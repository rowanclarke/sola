#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

typedef struct {
    float top;
    float left;
    float width;
    float height;
} Rectangle;

typedef struct {
    float word_spacing;
} Style;

typedef struct {
    const char* text;
    size_t len;
    Rectangle rect;
    Style style;
} Text;

void* chars_map(
  const unsigned char* usfm,
  size_t len,
  const unsigned int** out,
  size_t* out_len
);

void insert(
  void* map,
  unsigned int chr,
  float width,
  float height
);

void* layout(
  void* map,
  const unsigned char* usfm,
  size_t len
);

void page(
  void* layout,
  const Text** out,
  size_t* out_len
);
