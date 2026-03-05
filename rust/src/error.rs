use thiserror::Error;

#[derive(Error, Debug)]
pub enum SolaError {
    #[error("Serialization failed: {0}")]
    Serialization(String),

    #[error("Deserialization failed: {0}")]
    Deserialization(String),

    #[error("Font loading failed")]
    FontLoad,

    #[error("Missing book identifier")]
    MissingIdentifier,

    #[error("Model loading failed: {0}")]
    ModelLoad(String),

    #[error("Search failed: {0}")]
    Search(String),

    #[error("Missing index")]
    MissingIndex,
}
