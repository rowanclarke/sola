#include <stdlib.h>

void* load_model(
  const char* model,
  size_t model_len,
  const char* tokenizer,
  size_t tokenizer_len,
  char** out_error,
  size_t* out_error_len
);

void get_result(
  const void* model,
  const void* embeddings,
  const void* verse_refs,
  const char* query,
  size_t query_len,
  void*** out,
  float** out_distances,
  size_t* out_len,
  char** out_error,
  size_t* out_error_len
);

void search_index(
  const void* page_map,
  const char* query,
  size_t query_len,
  void*** out,
  size_t* out_len,
  char** out_error,
  size_t* out_error_len
);

void load_embeddings(
  const char* embeddings,
  size_t embeddings_len,
  const char* verse_refs,
  size_t verse_refs_len,
  void** out_embeddings,
  void** out_verse_refs
);
