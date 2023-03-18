/* globals */

#include <stdbool.h>
#include <unistd.h>

#include "ini.h"
#include "log.h"
/* #if EXPORT_INTERFACE */
#include "utstring.h"
#include "utarray.h"
/* #endif */


#include "s7.h"
#include "mibl_s7.h"

extern const UT_icd ut_str_icd;

extern bool bzl_mode;
extern int  verbosity;

s7_scheme *s7;

UT_string *setter;

/* FIXME: if var does not exist, create it.
   That way users can use globals to pass args to -main.
 */
EXPORT void mibl_s7_set_flag(char *flag, bool val) {
#if defined(DEBUG_TRACE)
    if (mibl_trace)
        log_trace("mibl_s7_set_flag: %s: %d", flag, val);
#endif
    s7_pointer fld = s7_name_to_value(s7, flag);
    if (fld == s7_undefined(s7)) {
        if (verbose && verbosity > 1)
            log_info("Flag %s undefined, defining as %d", flag, val);
        s7_define_variable(s7, flag, val? s7_t(s7) : s7_f(s7));
        return;
    }
    utstring_renew(setter);
    utstring_printf(setter, "(set! %s %s)",
                    flag, val? "#t": "#f");
#if defined(DEBUG_TRACE)
    if (mibl_debug) {
        log_debug("Setting s7 global var: %s", utstring_body(setter));
    }
#endif
    s7_eval_c_string(s7, utstring_body(setter));
}

LOCAL void mibl_s7_configure(void)
{
#if defined(DEBUG_TRACE)
    if (mibl_trace) {
        log_trace("mibl_s7_configure");
    }
#endif

    /* miblrc:  *mibl-dump-pkgs*, *mibl-scan-exclusions* */
    /* populate pkgs list, so scheme code can use it */
    char **p = NULL;
    s7_pointer _s7_pkgs = s7_nil(s7);
    while ( (p=(char**)utarray_next(mibl_config.pkgs, p))) {
#if defined(DEBUG_TRACE)
        if (mibl_debug) printf("Adding to pkgs list: %s\n", *p);
#endif
        _s7_pkgs = s7_cons(s7, s7_make_string(s7, *p), _s7_pkgs);
    }
    s7_define_variable(s7, "*mibl-dump-pkgs*", _s7_pkgs);

    /* populate exclusions list, so scheme code can use it */
    p = NULL;
    s7_pointer _s7_exclusions = s7_nil(s7);
    while ( (p=(char**)utarray_next(mibl_config.exclude_dirs, p))) {
#if defined(DEBUG_TRACE)
        if (mibl_debug_miblrc)
            log_debug("Adding to exlusions list: %s",*p);
#endif
        _s7_exclusions = s7_cons(s7, s7_make_string(s7, *p), _s7_exclusions);
    }
#if defined(DEBUG_TRACE)
    if (mibl_debug)
        log_debug("exclusions list: %s", TO_STR(_s7_exclusions));
#endif
    s7_define_variable(s7, "*mibl-scan-exclusions*", _s7_exclusions);
}

/* **************************************************************** */
// to configure we need scm dirs for *load-path*, ws_root for traversal
// to run we need main_script
// q: script runs load-project; doesn't that handle ws root?
EXPORT struct mibl_config_s *mibl_s7_init(char *scm_dir, char *ws_root)
{
    // scm_dir augments default *load-path*, which contains the mibl/scm dirs
#if defined(DEBUG_TRACE)
    if (mibl_trace) {
        log_debug("mibl_s7_init: scm dir: %s, wsroot: %s", scm_dir, ws_root);
    }
#endif
    /* config in this order: first bazel, then mibl, then s7 */
    bazel_configure(ws_root);

    /* log_debug("mibl_configure done"); */
    /* if (options[FLAG_ONLY_CONFIG].count) { */
    /*     log_info("configuration complete, exiting"); */
    /*     exit(EXIT_SUCCESS); */
    /* } */

    s7 = s7_configure(scm_dir, ws_root); //FIXME: ws_root not used by s7_configure?

    mibl_configure();           /* reads miblrc, sets struct mibl_config */

    mibl_s7_configure();        /* just some s7_define_variable */

    /* always run from base ws root, set by bazel_configure */
    /* for test targets base == runfiles dir */
    /* for std targets, base == ws root (possibly set by -w (--workspace) */
    chdir(rootws);

    utstring_new(setter);

    if (verbose) {
        log_info("pwd: %s", getcwd(NULL,0));
        log_info("*load-path*: %s", TO_STR(s7_load_path(s7)));
    }
    return &mibl_config;
}

/* run a script (which may or may not run load-project) */
EXPORT void mibl_s7_run(char *main_script, char *ws)
{
#if defined(DEBUG_TRACE)
    if (mibl_trace) {
        log_debug("mibl_run: %s, %s", main_script, ws);
        log_debug("mibl_run cwd: %s", getcwd(NULL, 0));
    }
#endif

    if (verbose) {
        log_debug("mibl_run: %s, %s", main_script, ws);
        log_debug("mibl_run cwd: %s", getcwd(NULL, 0));
    }

    if (s7_name_to_value(s7, "*mibl-debug-report*") == s7_t(s7)) {
        if (s7_name_to_value(s7, "*mibl-dev-mode*") == s7_t(s7)) {
            log_error("debug:report is incompatible with --dev");
            return;
        }
        mibl_config.emit_parsetree = true;
        mibl_s7_set_flag("*mibl-emit-mibl*", true);
        mibl_s7_set_flag("*mibl-emit-s7*", true);
        mibl_s7_set_flag("*mibl-emit-result*", true);
        log_debug("DEBUG REPORT");
    }

    if (s7_name_to_value(s7, "*mibl-show-config*") == s7_t(s7)) {
        show_bazel_config();
        show_mibl_config();
        show_s7_config();
        return;
    }

    /* 1. if dev-mode, load PARSETREE.s7, else run traversal, producing parsetree */
    /* 2. IF user provided -main, run it */

    UT_string *sexp;
    utstring_new(sexp);
    if (ws) {
        if (s7_name_to_value(s7, "*mibl-dev-mode*") == s7_t(s7)) {
            /* char *root = getcwd(NULL, 0); */
            utstring_printf(sexp, "%s",
                    "(define *mibl-project* "
                    "  (call-with-input-file \".mibl/PARSETREE.s7\" "
                    "    (lambda (p) "
                    "      (let* ((x (read p)) "
                    "             (y (eval (read (open-input-string x))))) "
                    "          y))))"
                    );
        } else {
            utstring_printf(sexp, "(mibl-load-project \"%s\")", ws);
        }
    } else {
        if (s7_name_to_value(s7, "*mibl-dev-mode*") == s7_t(s7)) {
            char *root = getcwd(NULL, 0);
            utstring_printf(sexp,
                    "(define *mibl-project* "
                    "  (call-with-input-file \"%s/.mibl/PARSETREE.s7\" "
                    "    (lambda (p) "
                    "      (let* ((x (read p)) "
                    "             (y (eval (read (open-input-string x))))) "
                    "          y))))",
                    root);
        } else {
            utstring_printf(sexp, "(mibl-load-project)");
        }
    }
    /* if (true) { */
    /*     log_debug("CWD: %s", getcwd(NULL, 0)); */
    /*     log_debug("load sexp: %s", utstring_body(sexp)); */
    /* } */

    s7_pointer result;
    int gc_loc = -1;
    const char *errmsg = NULL;
    /* trap error messages */
    s7_pointer old_port = s7_set_current_error_port(s7, s7_open_output_string(s7));
    if (old_port != s7_nil(s7))
        gc_loc = s7_gc_protect(s7, old_port);

    result = s7_eval_c_string(s7, utstring_body(sexp));

    /* look for error messages */
    errmsg = s7_get_output_string(s7, s7_current_error_port(s7));

    /* if we got something, wrap it in "[]" */
    s7_close_output_port(s7, s7_current_error_port(s7));
    s7_set_current_error_port(s7, old_port);
    if (gc_loc != -1)
        s7_gc_unprotect_at(s7, gc_loc);

    if ((errmsg) && (*errmsg)) {
        fprintf(stdout, "[%s]\n", errmsg);
        return;
    }

    /* char *s = TO_STR(ptree); */
    /* log_debug("PTREE: '%s'", ptree); */
    /* free(s); */
    /* (void)ptree; */

    utstring_free(sexp);

    if (main_script) {
        if (!s7_load(s7, main_script)) {
            log_error(RED "Could not load main_script '%s'; exiting\n",
                      main_script);
            fflush(NULL);
            exit(EXIT_FAILURE);
        }
    } else {
        log_info(GRN "INFO: " CRESET "main_script is NULL");
        /* exit(EXIT_FAILURE); */
        /* return; */
    }

    s7_pointer _main = s7_name_to_value(s7, "-main");

    if (_main == s7_undefined(s7)) {
        log_error(RED "Could not find procedure -main; exiting\n");
        exit(EXIT_FAILURE);
    }

    s7_pointer _s7_ws;
    if (ws) {
        _s7_ws = s7_make_string(s7, ws);
    } else {
        _s7_ws = s7_nil(s7);
    }

    s7_pointer _s7_args;

    /* if (rootpath) { */
    /*     _s7_args = s7_list(s7, 2, */
    /*                        s7_make_string(s7, rootpath), */
    /*                        _s7_ws); */
    /* } else { */
    _s7_args = s7_list(s7, 2,
                       s7_nil(s7),
                       _s7_ws);
    /* } */

#if defined(DEBUG_TRACE)
    if (mibl_debug) log_debug("s7 args: %s", TO_STR(_s7_args));
#endif

    /* s7_gc_on(s7, s7_f(s7)); */


    /* s7_int main_gc_loc = s7_gc_protect(s7, _main); */

    if (verbose && verbosity > 2)
        log_info("calling s7: %s", TO_STR(_main));

    /* **************************************************************** */
    /* this does the actual conversion: */
    result = s7_apply_function(s7, _main, _s7_args);
    (void)result; /* FIXME: check result */
    /* **************************************************************** */

    /* log_info("RESULT: %s\n", TO_STR(result)); */
    s7_gc_unprotect_at(s7, (s7_int)_main);

    errmsg = (char*)s7_get_output_string(s7, s7_current_error_port(s7));
    if ((errmsg) && (*errmsg)) {
        log_error("[%s\n]", errmsg);
        s7_quit(s7);
        exit(EXIT_FAILURE);
    }
}
