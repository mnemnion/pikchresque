/* Minimalist command-line filter: pikchr in, svg out, default configuration only.
 * 
 * This exists as a proof-of-life for the C FFI library. */


#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "pikchr.h"

static char *read_stdin(void) {
    size_t capacity = 4096;
    size_t length = 0;
    char *source = malloc(capacity);

    if (source == NULL) {
        return NULL;
    }

    for (;;) {
        if (length == capacity) {
            char *grown;

            if (capacity > SIZE_MAX / 2) {
                free(source);
                return NULL;
            }
            capacity *= 2;
            grown = realloc(source, capacity);
            if (grown == NULL) {
                free(source);
                return NULL;
            }
            source = grown;
        }

        length += fread(source + length, 1, capacity - length, stdin);
        if (ferror(stdin)) {
            free(source);
            return NULL;
        }
        if (feof(stdin)) {
            break;
        }
    }

    source[length] = '\0';
    return source;
}

int main(void) {
    char *source = read_stdin();
    char *output;
    int width;
    int status;

    if (source == NULL) {
        fputs("pik2svg: failed to read stdin\n", stderr);
        return EXIT_FAILURE;
    }

    output = pikchr(source, "pikchr", 0, &width, NULL);
    free(source);
    if (output == NULL) {
        fputs("pik2svg: pikchr ran out of memory\n", stderr);
        return EXIT_FAILURE;
    }

    status = width < 0 ? EXIT_FAILURE : EXIT_SUCCESS;
    if (fputs(output, stdout) == EOF) {
        status = EXIT_FAILURE;
    }
    free(output);
    return status;
}
