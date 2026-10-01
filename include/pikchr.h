#ifndef PIKCHR_H
#define PIKCHR_H

#ifdef __cplusplus
extern "C" {
#endif

/*
** Return parser errors as plain text. Without this flag, errors are
** HTML-formatted and safe to insert into an HTML output stream.
*/
#define PIKCHR_PLAINTEXT_ERRORS 0x0001u

/*
** Select the fixed dark-mode palette. This flag has no effect unless
** PIKCHR_SINGLE_COLOR is also set.
*/
#define PIKCHR_DARK_MODE        0x0002u

/*
** Mix a thread-local call counter into the generated SVG id. This gives
** separate ids to repeated renderings of the same script, which is useful
** when multiple copies of a diagram may appear in one document.
*/
#define PIKCHR_EXTRA_UNIQUE_ID  0x0004u

/*
** Emit fixed colors instead of responsive CSS light-dark() colors. The fixed
** palette is light unless PIKCHR_DARK_MODE is also set.
*/
#define PIKCHR_SINGLE_COLOR     0x0008u

/* Use the original RGB dark-mode conversion instead of OKLCH. */
#define PIKCHR_CLASSIC_COLORSPACE 0x0010u

/*
** Parse the PIKCHR script contained in source[]. Return an SVG rendering, or
** HTML-formatted error text if an error is encountered. If
** PIKCHR_PLAINTEXT_ERRORS is set, errors are returned as plain text instead.
**
** If width or height is not NULL, write the corresponding SVG dimension
** through it. A value of -1 is written when the script contains an error.
**
** If class_name is not NULL, include it as the class name in the SVG markup.
**
** The returned string is allocated by malloc() and must be released by the
** caller with free(). NULL is returned only when allocation fails.
*/
char *pikchr(
    const char *source,
    const char *class_name,
    unsigned int flags,
    int *width,
    int *height
);

#ifdef __cplusplus
}
#endif

#endif
