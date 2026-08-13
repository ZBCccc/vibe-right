#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <webp/encode.h>

typedef struct {
    const char *input_path;
    const char *output_path;
    float quality;
} EncoderOptions;

static void print_usage(const char *program) {
    fprintf(stderr, "Usage: %s [-quiet] [-q quality] input -o output\n", program);
}

static int parse_options(int argc, char *argv[], EncoderOptions *options) {
    options->input_path = NULL;
    options->output_path = NULL;
    options->quality = 90.0f;

    for (int index = 1; index < argc; ++index) {
        const char *argument = argv[index];
        if (strcmp(argument, "-quiet") == 0) {
            continue;
        }
        if (strcmp(argument, "-q") == 0) {
            if (++index >= argc) return 0;
            char *end = NULL;
            errno = 0;
            const float quality = strtof(argv[index], &end);
            if (errno != 0 || end == argv[index] || *end != '\0' || quality < 0.0f || quality > 100.0f) {
                return 0;
            }
            options->quality = quality;
            continue;
        }
        if (strcmp(argument, "-o") == 0) {
            if (++index >= argc || options->output_path != NULL) return 0;
            options->output_path = argv[index];
            continue;
        }
        if (argument[0] == '-' || options->input_path != NULL) return 0;
        options->input_path = argument;
    }

    return options->input_path != NULL && options->output_path != NULL;
}

static CGImageRef create_oriented_image(CGImageSourceRef source) {
    CGImageRef fallback = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    if (fallback == NULL) return NULL;

    const size_t width = CGImageGetWidth(fallback);
    const size_t height = CGImageGetHeight(fallback);
    const size_t maximum_dimension = width > height ? width : height;
    if (maximum_dimension == 0 || maximum_dimension > INT64_MAX) return fallback;

    int64_t maximum_dimension_value = (int64_t)maximum_dimension;
    CFNumberRef maximum_dimension_number = CFNumberCreate(
        kCFAllocatorDefault,
        kCFNumberSInt64Type,
        &maximum_dimension_value
    );
    if (maximum_dimension_number == NULL) return fallback;

    const void *keys[] = {
        kCGImageSourceCreateThumbnailFromImageAlways,
        kCGImageSourceCreateThumbnailWithTransform,
        kCGImageSourceThumbnailMaxPixelSize,
        kCGImageSourceShouldCacheImmediately
    };
    const void *values[] = {
        kCFBooleanTrue,
        kCFBooleanTrue,
        maximum_dimension_number,
        kCFBooleanTrue
    };
    CFDictionaryRef options = CFDictionaryCreate(
        kCFAllocatorDefault,
        keys,
        values,
        4,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks
    );
    CFRelease(maximum_dimension_number);
    if (options == NULL) return fallback;

    CGImageRef oriented = CGImageSourceCreateThumbnailAtIndex(source, 0, options);
    CFRelease(options);
    if (oriented == NULL) return fallback;
    CGImageRelease(fallback);
    return oriented;
}

static int write_all(int descriptor, const uint8_t *bytes, size_t count) {
    size_t written = 0;
    while (written < count) {
        const ssize_t result = write(descriptor, bytes + written, count - written);
        if (result < 0) {
            if (errno == EINTR) continue;
            return 0;
        }
        if (result == 0) return 0;
        written += (size_t)result;
    }
    return 1;
}

static void unpremultiply_rgba(uint8_t *pixels, size_t pixel_count) {
    for (size_t index = 0; index < pixel_count; ++index) {
        uint8_t *pixel = pixels + index * 4;
        const uint32_t alpha = pixel[3];
        if (alpha == 0 || alpha == 255) continue;
        for (size_t component = 0; component < 3; ++component) {
            uint32_t value = ((uint32_t)pixel[component] * 255U + alpha / 2U) / alpha;
            pixel[component] = (uint8_t)(value > 255U ? 255U : value);
        }
    }
}

static int encode_image(const EncoderOptions *options) {
    int status = 1;
    CFURLRef input_url = NULL;
    CGImageSourceRef source = NULL;
    CGImageRef image = NULL;
    CGColorSpaceRef color_space = NULL;
    CGContextRef context = NULL;
    uint8_t *rgba = NULL;
    uint8_t *webp = NULL;
    int output_descriptor = -1;

    input_url = CFURLCreateFromFileSystemRepresentation(
        kCFAllocatorDefault,
        (const UInt8 *)options->input_path,
        (CFIndex)strlen(options->input_path),
        false
    );
    if (input_url == NULL) {
        fprintf(stderr, "Could not read the input path.\n");
        goto cleanup;
    }

    source = CGImageSourceCreateWithURL(input_url, NULL);
    if (source == NULL || CGImageSourceGetCount(source) == 0) {
        fprintf(stderr, "The input is not a supported image.\n");
        goto cleanup;
    }

    image = create_oriented_image(source);
    if (image == NULL) {
        fprintf(stderr, "Could not decode the input image.\n");
        goto cleanup;
    }

    const size_t width = CGImageGetWidth(image);
    const size_t height = CGImageGetHeight(image);
    if (width == 0 || height == 0 || width > INT_MAX / 4 || height > INT_MAX) {
        fprintf(stderr, "The input image dimensions are unsupported.\n");
        goto cleanup;
    }
    const size_t stride = width * 4;
    if (height > SIZE_MAX / stride) {
        fprintf(stderr, "The input image is too large.\n");
        goto cleanup;
    }

    rgba = (uint8_t *)calloc(height, stride);
    color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (rgba == NULL || color_space == NULL) {
        fprintf(stderr, "Could not allocate the image buffer.\n");
        goto cleanup;
    }

    context = CGBitmapContextCreate(
        rgba,
        width,
        height,
        8,
        stride,
        color_space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
    );
    if (context == NULL) {
        fprintf(stderr, "Could not create the image renderer.\n");
        goto cleanup;
    }

    CGContextTranslateCTM(context, 0.0, (CGFloat)height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextDrawImage(context, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), image);
    unpremultiply_rgba(rgba, width * height);

    const size_t webp_size = WebPEncodeRGBA(
        rgba,
        (int)width,
        (int)height,
        (int)stride,
        options->quality,
        &webp
    );
    if (webp_size == 0 || webp == NULL) {
        fprintf(stderr, "WebP encoding failed.\n");
        goto cleanup;
    }

    output_descriptor = open(options->output_path, O_WRONLY | O_CREAT | O_EXCL, 0644);
    if (output_descriptor < 0) {
        fprintf(stderr, "Could not create the output file: %s\n", strerror(errno));
        goto cleanup;
    }
    if (!write_all(output_descriptor, webp, webp_size) || fsync(output_descriptor) != 0) {
        fprintf(stderr, "Could not write the output file: %s\n", strerror(errno));
        goto cleanup;
    }
    if (close(output_descriptor) != 0) {
        output_descriptor = -1;
        fprintf(stderr, "Could not finish the output file: %s\n", strerror(errno));
        goto cleanup;
    }
    output_descriptor = -1;
    status = 0;

cleanup:
    if (output_descriptor >= 0) close(output_descriptor);
    if (status != 0) unlink(options->output_path);
    if (webp != NULL) WebPFree(webp);
    if (context != NULL) CGContextRelease(context);
    if (color_space != NULL) CGColorSpaceRelease(color_space);
    free(rgba);
    if (image != NULL) CGImageRelease(image);
    if (source != NULL) CFRelease(source);
    if (input_url != NULL) CFRelease(input_url);
    return status;
}

int main(int argc, char *argv[]) {
    EncoderOptions options;
    if (!parse_options(argc, argv, &options)) {
        print_usage(argv[0]);
        return 2;
    }
    return encode_image(&options);
}
