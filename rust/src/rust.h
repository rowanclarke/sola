#include <stdlib.h>

typedef struct {
  const char* font_family;
  size_t font_family_len;
  float font_size;
  float height;
  float letter_spacing;
  float word_spacing;
} TextStyle;

typedef enum {
  VERSE = 0,
  NORMAL = 1,
  HEADER = 2,
  CHAPTER = 3,
} Style;

typedef struct {
  float top;
  float left;
  float width;
  float height;
} Rectangle;

typedef struct {
  const char* text;
  size_t len;
  Rectangle rect;
  TextStyle style;
} Text;

typedef struct {
  float width;
  float height;
  float header_height;
  float header_padding;
} Dimensions;

void* renderer();
void register_font_family(void* renderer, char* family, size_t family_len, char* data, size_t len);
void register_style(void* renderer, Style style, TextStyle* textStyle);

void* layout(
  void* renderer,
  const char* usfm,
  size_t len,
  Dimensions* dim
);

void page(
  void* layout,
  const Text** out,
  size_t* out_len
);
