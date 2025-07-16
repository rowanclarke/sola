#include <stdlib.h>

void* load_model(
  const char* embeddings,
  size_t embeddings_len,
  const char* lines,
  size_t lines_len,
  const char* model,
  size_t model_len,
  const char* tokenizer,
  size_t tokenizer_len
);

void get_result(
  const void* model,
  const char* query,
  size_t query_len,
  const char** out,
  size_t* out_len
);
