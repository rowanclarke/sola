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

typedef enum {
  VERSE = 0,
  NORMAL = 1,
} Style;

typedef struct {
  float top;
  float left;
  float width;
  float height;
} Rectangle;

typedef struct {
  Style style;
  float word_spacing;
} TextStyle;

typedef struct {
  const char* text;
  size_t len;
  Rectangle rect;
  TextStyle style;
} Text;

typedef struct {
  float width;
  float height;
  float line_height;
} Dimensions;

void* chars_map(
  const unsigned char* usfm,
  size_t len,
  const unsigned int** out,
  size_t* out_len
);

void insert(
  void* map,
  unsigned int chr,
  Style style,
  float width
);

void* layout(
  void* map,
  const unsigned char* usfm,
  size_t len,
  Dimensions* dim
);

void page(
  void* layout,
  const Text** out,
  size_t* out_len
);
