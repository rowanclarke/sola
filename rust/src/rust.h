#include <stdlib.h>

typedef struct {
  const char* font_family;
  size_t font_family_len;
  float font_size;
  float height;
  float letter_spacing;
  float word_spacing;
  int underline;
} TextStyle;

typedef enum {
  VERSE = 0,
  NORMAL = 1,
  HEADER = 2,
  CHAPTER = 3,
  WORD = 4,

  CALLER = 9,
  FOOTNOTE = 10,
  CROSSREF = 11,
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
  float drop_cap_padding;
} Dimensions;

void free_error(char* error, size_t error_len);
void bytes_free(char* bytes, size_t len);

void* renderer();
void register_font_family(void* renderer, char* family, size_t family_len, char* data, size_t len, char** out_error, size_t* out_error_len);
void register_style(void* renderer, Style style, TextStyle* textStyle);

void serialize_usfm(const char* usfm, size_t usfm_len, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);
void* archived_book(const char* book, size_t book_len, char** out_error, size_t* out_error_len);
void book_identifier(void* usfm, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);

void* layout(void* renderer, void* usfm, Dimensions* dim, char** out_error, size_t* out_error_len);
void serialize_pages(void* painter, const char** out, size_t* out_len, const char** out_index, size_t* out_index_len, char** out_error, size_t* out_error_len);
void page_from_bytes(void* renderer, const char* page, size_t page_len, const Text** out, size_t* out_len, char** out_error, size_t* out_error_len);
void page_free(Text* page, size_t len);

void serialize_indices(void* painter, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);
void serialize_verses(void* painter, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);
void serialize_verse_ranges(void* painter, const char** out, size_t* out_len);
