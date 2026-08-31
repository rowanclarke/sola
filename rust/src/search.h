#include <stdlib.h>

void* load_search_engine(
  const char* model,
  size_t model_len,
  const char* tokenizer,
  size_t tokenizer_len,
  const char* hnsw_dir,
  size_t hnsw_dir_len,
  const char* hnsw_basename,
  size_t hnsw_basename_len,
  const char* idx,
  size_t idx_len,
  char** out_error,
  size_t* out_error_len
);

void search(
  const void* engine,
  const char* query,
  size_t query_len,
  size_t top_k,
  size_t ef,
  size_t** out_ids,
  float** out_distances,
  size_t* out_len,
  char** out_error,
  size_t* out_error_len
);

void get_search_result(
  const void* engine,
  const void* ref_index,
  size_t id,
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
