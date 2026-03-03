#include <stdlib.h>

typedef struct {
  const char* book;
  size_t book_len;
  const char* header;
  size_t header_len;
} BookIndex;

void* load_model(
  const char* embeddings,
  size_t embeddings_len,
  const char* verses,
  size_t verses_len,
  const char* model,
  size_t model_len,
  const char* tokenizer,
  size_t tokenizer_len,
  char** out_error,
  size_t* out_error_len
);

void* get_result(
  const void* model,
  const char* query,
  size_t query_len,
  char** out_error,
  size_t* out_error_len
);

void* get_search();

void add_book(
  void* search,
  const char* id,
  size_t id_len,
  const void* book
);

void search_index(
  const void* indexer,
  const char* query,
  size_t query_len,
  BookIndex** out,
  size_t* out_len
);
