/* tcllunasvg.cpp — Tcl-Binding für lunasvg
 *
 * Eine eigenständige Tcl-Erweiterung für SVG-Rendering via lunasvg.
 * Keine Abhängigkeit zu Tk oder Cairo. Output: PNG-Datei oder
 * ARGB32-Byte-Puffer.
 *
 * Tcl-API (object-handle Pattern, wie tclmcairo):
 *
 *   set doc [tcllunasvg::load file   "logo.svg"]
 *   set doc [tcllunasvg::load data   $svg_string]
 *
 *   $doc width                   -> double
 *   $doc height                  -> double
 *   $doc size                    -> {w h}
 *   $doc apply_stylesheet $css
 *   $doc to_png    filename ?-width W? ?-height H? ?-scale S? ?-bg COLOR?
 *   $doc to_argb32          ?-width W? ?-height H? ?-scale S? ?-bg COLOR?
 *                                -> dict {width N height M stride S data <bytes>}
 *   $doc destroy
 *
 * Utility:
 *   tcllunasvg::version                              -> "3.5.0"
 *   tcllunasvg::version_number                       -> 30500
 *   tcllunasvg::font_add family bold italic filename -> 0|1
 *   tcllunasvg::file_to_png in.svg out.png ?opts?    -> Bequemer One-Shot
 *
 * Build: TEA, siehe configure.in / Makefile.in
 * License: BSD 2-Clause
 * Part of the tclmcairo family — https://github.com/gregnix/tcllunasvg
 */

#include <tcl.h>
#include <lunasvg.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <string>

#ifndef PACKAGE_NAME
#  define PACKAGE_NAME "tcllunasvg"
#endif
#ifndef PACKAGE_VERSION
#  define PACKAGE_VERSION "0.1.1"
#endif

/* ================================================================== */
/* Document Handle Registry                                            */
/* ================================================================== */

struct DocHandle {
    std::unique_ptr<lunasvg::Document> doc;
};

static std::map<std::string, DocHandle*> g_handles;
static long g_id_counter = 0;

static std::string new_handle_name() {
    char buf[64];
    std::snprintf(buf, sizeof(buf), "::tcllunasvg::doc%ld", ++g_id_counter);
    return std::string(buf);
}

/* ================================================================== */
/* Option parsing helpers                                              */
/* ================================================================== */

struct RenderOptions {
    int      width  = -1;       /* -1 = use document width  */
    int      height = -1;       /* -1 = use document height */
    double   scale  = 0.0;      /* 0  = no scale            */
    uint32_t bgcolor = 0x00000000;  /* default transparent  */
};

/* Parse a color string: "0xAARRGGBB", "#RRGGBB", "#RGB", or named subset
 * (white/black/transparent). Returns 1 on success, 0 on parse error.   */
static int parse_color(const char* s, uint32_t* out) {
    if (s == nullptr || *s == '\0') return 0;

    if (std::strcmp(s, "transparent") == 0) { *out = 0x00000000; return 1; }
    if (std::strcmp(s, "white")       == 0) { *out = 0xFFFFFFFF; return 1; }
    if (std::strcmp(s, "black")       == 0) { *out = 0xFF000000; return 1; }

    /* 0xAARRGGBB form */
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        char* end = nullptr;
        unsigned long v = std::strtoul(s + 2, &end, 16);
        if (end != s + 2 && *end == '\0') { *out = (uint32_t)v; return 1; }
        return 0;
    }
    /* #RRGGBB or #AARRGGBB or #RGB */
    if (s[0] == '#') {
        const char* hex = s + 1;
        size_t len = std::strlen(hex);
        char* end = nullptr;
        unsigned long v = std::strtoul(hex, &end, 16);
        if (end != hex + len) return 0;
        if (len == 3) {
            unsigned r = (v >> 8) & 0xF, g = (v >> 4) & 0xF, b = v & 0xF;
            *out = 0xFF000000u | (r * 0x110000u) | (g * 0x1100u) | (b * 0x11u);
            return 1;
        }
        if (len == 6) { *out = 0xFF000000u | (uint32_t)v; return 1; }
        if (len == 8) { *out = (uint32_t)v; return 1; }
        return 0;
    }
    return 0;
}

/* Parse a sequence of objv into a RenderOptions struct.
 * Recognised options: -width INT, -height INT, -scale FLOAT, -bg COLOR.
 * Returns TCL_OK on success, TCL_ERROR on bad option/value (interp result set). */
static int parse_render_options(Tcl_Interp* interp, int objc, Tcl_Obj* const objv[],
                                RenderOptions* opt)
{
    for (int i = 0; i < objc; i += 2) {
        const char* opt_name = Tcl_GetString(objv[i]);
        if (i + 1 >= objc) {
            Tcl_SetObjResult(interp,
                Tcl_ObjPrintf("missing value for option %s", opt_name));
            return TCL_ERROR;
        }
        if (std::strcmp(opt_name, "-width") == 0) {
            if (Tcl_GetIntFromObj(interp, objv[i + 1], &opt->width) != TCL_OK)
                return TCL_ERROR;
        } else if (std::strcmp(opt_name, "-height") == 0) {
            if (Tcl_GetIntFromObj(interp, objv[i + 1], &opt->height) != TCL_OK)
                return TCL_ERROR;
        } else if (std::strcmp(opt_name, "-scale") == 0) {
            if (Tcl_GetDoubleFromObj(interp, objv[i + 1], &opt->scale) != TCL_OK)
                return TCL_ERROR;
        } else if (std::strcmp(opt_name, "-bg") == 0) {
            const char* colorstr = Tcl_GetString(objv[i + 1]);
            if (!parse_color(colorstr, &opt->bgcolor)) {
                Tcl_SetObjResult(interp,
                    Tcl_ObjPrintf("bad color value \"%s\": expected 0xAARRGGBB, "
                                  "#RRGGBB, #AARRGGBB, #RGB, or "
                                  "transparent/white/black", colorstr));
                return TCL_ERROR;
            }
        } else {
            Tcl_SetObjResult(interp,
                Tcl_ObjPrintf("bad option \"%s\": must be -width, -height, "
                              "-scale, or -bg", opt_name));
            return TCL_ERROR;
        }
    }
    return TCL_OK;
}

/* Compute final render dimensions from options + document size.
 * If scale > 0, dimensions are derived from doc * scale, ignoring -width/-height.
 * Otherwise: -width/-height override, defaulting to doc dimensions.            */
static void compute_render_size(const lunasvg::Document* doc, const RenderOptions& opt,
                                int* rw, int* rh)
{
    if (opt.scale > 0.0) {
        *rw = (int)(doc->width()  * opt.scale + 0.5);
        *rh = (int)(doc->height() * opt.scale + 0.5);
    } else {
        *rw = (opt.width  > 0) ? opt.width  : (int)(doc->width()  + 0.5);
        *rh = (opt.height > 0) ? opt.height : (int)(doc->height() + 0.5);
    }
    if (*rw < 1) *rw = 1;
    if (*rh < 1) *rh = 1;
}

/* ================================================================== */
/* Document subcommand handler: $doc <subcmd> <args>                   */
/* ================================================================== */

static int DocObjCmd(ClientData cd, Tcl_Interp* interp,
                     int objc, Tcl_Obj* const objv[])
{
    DocHandle* h = (DocHandle*)cd;
    if (h == nullptr || h->doc == nullptr) {
        Tcl_SetResult(interp, (char*)"invalid document handle", TCL_STATIC);
        return TCL_ERROR;
    }

    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?args?");
        return TCL_ERROR;
    }

    const char* sub = Tcl_GetString(objv[1]);

    /* ---- $doc width ---------------------------------------------- */
    if (std::strcmp(sub, "width") == 0) {
        Tcl_SetObjResult(interp, Tcl_NewDoubleObj((double)h->doc->width()));
        return TCL_OK;
    }
    /* ---- $doc height --------------------------------------------- */
    if (std::strcmp(sub, "height") == 0) {
        Tcl_SetObjResult(interp, Tcl_NewDoubleObj((double)h->doc->height()));
        return TCL_OK;
    }
    /* ---- $doc size  ---------------------------------------------- */
    if (std::strcmp(sub, "size") == 0) {
        Tcl_Obj* list = Tcl_NewListObj(0, nullptr);
        Tcl_ListObjAppendElement(interp, list, Tcl_NewDoubleObj((double)h->doc->width()));
        Tcl_ListObjAppendElement(interp, list, Tcl_NewDoubleObj((double)h->doc->height()));
        Tcl_SetObjResult(interp, list);
        return TCL_OK;
    }
    /* ---- $doc apply_stylesheet CSS  ------------------------------ */
    if (std::strcmp(sub, "apply_stylesheet") == 0) {
        if (objc != 3) {
            Tcl_WrongNumArgs(interp, 2, objv, "css-text");
            return TCL_ERROR;
        }
        Tcl_Size css_len = 0;
        const char* css = Tcl_GetStringFromObj(objv[2], &css_len);
        h->doc->applyStyleSheet(std::string(css, (size_t)css_len));
        return TCL_OK;
    }
    /* ---- $doc to_png filename ?opts? ----------------------------- */
    if (std::strcmp(sub, "to_png") == 0) {
        if (objc < 3) {
            Tcl_WrongNumArgs(interp, 2, objv, "filename ?-width W? ?-height H? ?-scale S? ?-bg COLOR?");
            return TCL_ERROR;
        }
        const char* filename = Tcl_GetString(objv[2]);
        RenderOptions opt;
        if (parse_render_options(interp, objc - 3, objv + 3, &opt) != TCL_OK)
            return TCL_ERROR;
        int rw = 0, rh = 0;
        compute_render_size(h->doc.get(), opt, &rw, &rh);
        lunasvg::Bitmap bitmap = h->doc->renderToBitmap(rw, rh, opt.bgcolor);
        if (!bitmap.valid()) {
            Tcl_SetResult(interp, (char*)"renderToBitmap failed", TCL_STATIC);
            return TCL_ERROR;
        }
        if (!bitmap.writeToPng(std::string(filename))) {
            Tcl_SetObjResult(interp,
                Tcl_ObjPrintf("could not write PNG to \"%s\"", filename));
            return TCL_ERROR;
        }
        return TCL_OK;
    }
    /* ---- $doc to_argb32 ?opts? ----------------------------------- */
    if (std::strcmp(sub, "to_argb32") == 0) {
        RenderOptions opt;
        if (parse_render_options(interp, objc - 2, objv + 2, &opt) != TCL_OK)
            return TCL_ERROR;
        int rw = 0, rh = 0;
        compute_render_size(h->doc.get(), opt, &rw, &rh);
        lunasvg::Bitmap bitmap = h->doc->renderToBitmap(rw, rh, opt.bgcolor);
        if (!bitmap.valid()) {
            Tcl_SetResult(interp, (char*)"renderToBitmap failed", TCL_STATIC);
            return TCL_ERROR;
        }
        int w = bitmap.width();
        int hgt = bitmap.height();
        int stride = bitmap.stride();
        uint8_t* data = bitmap.data();

        /* Build result dict */
        Tcl_Obj* dict = Tcl_NewDictObj();
        Tcl_DictObjPut(interp, dict, Tcl_NewStringObj("width", -1),  Tcl_NewIntObj(w));
        Tcl_DictObjPut(interp, dict, Tcl_NewStringObj("height", -1), Tcl_NewIntObj(hgt));
        Tcl_DictObjPut(interp, dict, Tcl_NewStringObj("stride", -1), Tcl_NewIntObj(stride));
        Tcl_DictObjPut(interp, dict, Tcl_NewStringObj("data", -1),
            Tcl_NewByteArrayObj(data, stride * hgt));
        Tcl_SetObjResult(interp, dict);
        return TCL_OK;
    }
    /* ---- $doc destroy -------------------------------------------- */
    if (std::strcmp(sub, "destroy") == 0) {
        const char* cmdname = Tcl_GetString(objv[0]);
        Tcl_DeleteCommand(interp, cmdname);
        /* Memory release done by command-delete callback. */
        return TCL_OK;
    }

    Tcl_SetObjResult(interp,
        Tcl_ObjPrintf("bad subcommand \"%s\": must be width, height, size, "
                      "apply_stylesheet, to_png, to_argb32, or destroy", sub));
    return TCL_ERROR;
}

/* Command-delete callback: free the handle. */
static void DocCmdDeleteProc(ClientData cd) {
    DocHandle* h = (DocHandle*)cd;
    if (h == nullptr) return;

    /* Remove from registry. The handle name equals the command name. */
    for (auto it = g_handles.begin(); it != g_handles.end(); ++it) {
        if (it->second == h) { g_handles.erase(it); break; }
    }
    delete h;
}

/* ================================================================== */
/* tcllunasvg::load <file|data> <arg>                                  */
/* ================================================================== */

static int LoadCmd(ClientData cd, Tcl_Interp* interp,
                   int objc, Tcl_Obj* const objv[])
{
    (void)cd;
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "file|data argument");
        return TCL_ERROR;
    }
    const char* mode = Tcl_GetString(objv[1]);

    std::unique_ptr<lunasvg::Document> doc;
    if (std::strcmp(mode, "file") == 0) {
        const char* filename = Tcl_GetString(objv[2]);
        doc = lunasvg::Document::loadFromFile(std::string(filename));
        if (!doc) {
            Tcl_SetObjResult(interp,
                Tcl_ObjPrintf("could not load SVG file \"%s\"", filename));
            return TCL_ERROR;
        }
    } else if (std::strcmp(mode, "data") == 0) {
        Tcl_Size data_len = 0;
        const char* data = Tcl_GetStringFromObj(objv[2], &data_len);
        doc = lunasvg::Document::loadFromData(data, (size_t)data_len);
        if (!doc) {
            Tcl_SetResult(interp, (char*)"could not parse SVG data", TCL_STATIC);
            return TCL_ERROR;
        }
    } else {
        Tcl_SetObjResult(interp,
            Tcl_ObjPrintf("bad source \"%s\": must be file or data", mode));
        return TCL_ERROR;
    }

    /* Register handle and create the per-document command. */
    DocHandle* h = new DocHandle();
    h->doc = std::move(doc);
    std::string name = new_handle_name();
    g_handles[name] = h;

    Tcl_CreateObjCommand(interp, name.c_str(), DocObjCmd,
                         (ClientData)h, DocCmdDeleteProc);
    Tcl_SetObjResult(interp, Tcl_NewStringObj(name.c_str(), -1));
    return TCL_OK;
}

/* ================================================================== */
/* tcllunasvg::version                                                 */
/* ================================================================== */

static int VersionCmd(ClientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, "");
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(lunasvg_version_string(), -1));
    return TCL_OK;
}

static int VersionNumberCmd(ClientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, "");
        return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(lunasvg_version()));
    return TCL_OK;
}

/* ================================================================== */
/* tcllunasvg::font_add family bold italic filename                    */
/* ================================================================== */

static int FontAddCmd(ClientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc != 5) {
        Tcl_WrongNumArgs(interp, 1, objv, "family bold italic filename");
        return TCL_ERROR;
    }
    const char* family   = Tcl_GetString(objv[1]);
    int bold = 0, italic = 0;
    if (Tcl_GetBooleanFromObj(interp, objv[2], &bold)   != TCL_OK) return TCL_ERROR;
    if (Tcl_GetBooleanFromObj(interp, objv[3], &italic) != TCL_OK) return TCL_ERROR;
    const char* filename = Tcl_GetString(objv[4]);

    bool ok = lunasvg_add_font_face_from_file(family, bold != 0, italic != 0, filename);
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(ok));
    return TCL_OK;
}

/* ================================================================== */
/* tcllunasvg::file_to_png in.svg out.png ?opts?                       */
/*                                                                     */
/* Convenience one-shot — load, render, write, free. No handle exposed. */
/* ================================================================== */

static int FileToPngCmd(ClientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]) {
    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv,
            "in.svg out.png ?-width W? ?-height H? ?-scale S? ?-bg COLOR?");
        return TCL_ERROR;
    }
    const char* in_file  = Tcl_GetString(objv[1]);
    const char* out_file = Tcl_GetString(objv[2]);

    RenderOptions opt;
    if (parse_render_options(interp, objc - 3, objv + 3, &opt) != TCL_OK)
        return TCL_ERROR;

    auto doc = lunasvg::Document::loadFromFile(std::string(in_file));
    if (!doc) {
        Tcl_SetObjResult(interp,
            Tcl_ObjPrintf("could not load SVG file \"%s\"", in_file));
        return TCL_ERROR;
    }
    int rw = 0, rh = 0;
    compute_render_size(doc.get(), opt, &rw, &rh);
    lunasvg::Bitmap bitmap = doc->renderToBitmap(rw, rh, opt.bgcolor);
    if (!bitmap.valid()) {
        Tcl_SetResult(interp, (char*)"renderToBitmap failed", TCL_STATIC);
        return TCL_ERROR;
    }
    if (!bitmap.writeToPng(std::string(out_file))) {
        Tcl_SetObjResult(interp,
            Tcl_ObjPrintf("could not write PNG to \"%s\"", out_file));
        return TCL_ERROR;
    }
    return TCL_OK;
}

/* ================================================================== */
/* Package init                                                        */
/* ================================================================== */

extern "C" {

#ifdef _WIN32
__declspec(dllexport)
#endif
int Tcllunasvg_Init(Tcl_Interp* interp) {
    if (Tcl_InitStubs(interp, "8.6-", 0) == nullptr) {
        return TCL_ERROR;
    }

    /* Create the namespace once. */
    if (Tcl_Eval(interp, "namespace eval ::tcllunasvg {}") != TCL_OK) {
        return TCL_ERROR;
    }

    Tcl_CreateObjCommand(interp, "::tcllunasvg::load",
        LoadCmd, nullptr, nullptr);
    Tcl_CreateObjCommand(interp, "::tcllunasvg::version",
        VersionCmd, nullptr, nullptr);
    Tcl_CreateObjCommand(interp, "::tcllunasvg::version_number",
        VersionNumberCmd, nullptr, nullptr);
    Tcl_CreateObjCommand(interp, "::tcllunasvg::font_add",
        FontAddCmd, nullptr, nullptr);
    Tcl_CreateObjCommand(interp, "::tcllunasvg::file_to_png",
        FileToPngCmd, nullptr, nullptr);

    if (Tcl_PkgProvide(interp, PACKAGE_NAME, PACKAGE_VERSION) != TCL_OK) {
        return TCL_ERROR;
    }
    return TCL_OK;
}

} /* extern "C" */
