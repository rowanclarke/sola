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

void* renderer();
void register_font_family(void* renderer, char* family, size_t family_len, char* data, size_t len, char** out_error, size_t* out_error_len);
void register_style(void* renderer, Style style, TextStyle* textStyle);

void serialize_usfm(const char* usfm, size_t usfm_len, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);
void* archived_book(const char* book, size_t book_len, char** out_error, size_t* out_error_len);
void book_identifier(void* usfm, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);

void* layout(void* renderer, void* usfm, Dimensions* dim, char** out_error, size_t* out_error_len);
void serialize_pages(void* painter, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);
void* archived_pages(const char* pages, size_t pages_len, char** out_error, size_t* out_error_len);
size_t num_pages(void* archived_pages);
void page(void* renderer, void* archived_pages, size_t n, const Text** out, size_t* out_len, char** out_error, size_t* out_error_len);

void serialize_indices(void* painter, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);
void* archived_indices(const char* indices, size_t indices_len, char** out_error, size_t* out_error_len);
void get_index(
  void* archived_indices,
  void* index,
  size_t* out_page,
  const char** out_book,
  size_t* out_book_len,
  const char** out_header,
  size_t* out_header_len,
  unsigned short* out_chapter,
  unsigned short* out_verse,
  char** out_error,
  size_t* out_error_len
);
void serialize_verses(void* painter, const char** out, size_t* out_len, char** out_error, size_t* out_error_len);
