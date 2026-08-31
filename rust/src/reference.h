#include <stdlib.h>

// One reference-search hit. `book` and `header` point into the RefIndex that
// produced the hit and stay valid for as long as it lives; only the array
// itself needs freeing, via ref_hits_free.
// A `chapter` or `verse` of 0 means the hit stops at the level above: a book
// hit carries neither, a chapter hit carries only a chapter.
typedef struct {
  size_t page;
  const char* book;
  size_t book_len;
  const char* header;
  size_t header_len;
  unsigned short chapter;
  unsigned short verse;
} RefHit;

void* ref_index_builder_new();

void ref_index_builder_add(
  void* builder,
  const char* data,
  size_t data_len,
  char** out_error,
  size_t* out_error_len
);

void* ref_index_builder_finish(
  void* builder,
  char** out_error,
  size_t* out_error_len
);

void ref_index_free(void* index);

void ref_index_lookup(
  const void* index,
  const char* query,
  size_t query_len,
  size_t limit,
  const RefHit** out,
  size_t* out_len,
  char** out_error,
  size_t* out_error_len
);

void ref_hits_free(RefHit* hits, size_t len);

void indices_book_title(
  const char* data,
  size_t data_len,
  const char** out,
  size_t* out_len,
  char** out_error,
  size_t* out_error_len
);
