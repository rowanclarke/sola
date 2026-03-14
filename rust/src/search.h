#include <stdlib.h>

void* load_model(
  const char* model,
  size_t model_len,
  const char* tokenizer,
  size_t tokenizer_len,
  char** out_error,
  size_t* out_error_len
);

void* get_result(
  const void* model,
  const void* embeddings,
  const void* verses,
  const char* query,
  size_t query_len,
  char** out_error,
  size_t* out_error_len
);

void search_index(
  const void* archived_indices,
  const char* query,
  size_t query_len,
  void*** out,
  size_t* out_len,
  char** out_error,
  size_t* out_error_len
);

void* get_model(
  const char* model,
  size_t model_len,
  const char* tokenizer,
  size_t tokenizer_len,
  char** out_error,
  size_t* out_error_len
);

void get_embeddings(
  const void* model,
  const void* archived_book,
  const char** out_embeddings,
  size_t* out_embeddings_len,
  const char** out_verses,
  size_t* out_verses_len,
  char** out_error,
  size_t* out_error_len
);

void load_embeddings_data(
  const char* embeddings,
  size_t embeddings_len,
  const char* verses,
  size_t verses_len,
  void** out_embeddings,
  void** out_verses
);
