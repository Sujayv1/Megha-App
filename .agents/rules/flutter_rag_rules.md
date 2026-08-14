# Workspace Rule: Direct RAG Integration (Gemini 3.6 Flash & Chroma Cloud)

This guideline defines the standard serverless Retrieval-Augmented Generation (RAG) architecture for the Megha application using Chroma Cloud vector search and Gemini 3.6 Flash.

## 1. Environment Credentials & Configuration

- **Gemini API Key**: Defined in `AppConstants.geminiApiKey`
- **Gemini Generation Model**: `gemini-3.6-flash`
- **Gemini Embedding Model**: `gemini-embedding-001`
- **Chroma Cloud Tenant ID**: `5b24e72b-47d9-467c-b55e-288db51e3e55`
- **Chroma Cloud Database**: `megha`
- **Chroma Cloud Collection**: `megharag_docs`
- **Chroma Cloud API Key**: `ck-45asi2qrJPZHUcf3EqmyfWiGSidHSo8cwAYa92ju7fKF`

---

## 2. API Endpoints & Specifications

### A. Gemini Query Embeddings
- **URL**: `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=<GEMINI_API_KEY>`
- **Headers**: `Content-Type: application/json`
- **Payload**:
  ```json
  {
    "model": "models/gemini-embedding-001",
    "content": {
      "parts": [{"text": "<USER_QUERY>"}]
    },
    "outputDimensionality": 3072
  }
  ```
- **Parsing**: Extract `List<double>` from `data['embedding']['values']` (3072-dimension float vector).

### B. Chroma Cloud Collection Lookup (v2 API)
- **URL**: `GET https://api.trychroma.com/api/v2/tenants/<TENANT_ID>/databases/<DATABASE>/collections/<COLLECTION_NAME>`
- **Headers**:
  - `Content-Type: application/json`
  - `x-chroma-token: <CHROMA_API_KEY>`
- **Parsing**: Extract Collection UUID from `data['id']`.

### C. Chroma Cloud Vector Query (v2 API)
- **URL**: `POST https://api.trychroma.com/api/v2/tenants/<TENANT_ID>/databases/<DATABASE>/collections/<COLLECTION_UUID>/query`
- **Headers**:
  - `Content-Type: application/json`
  - `x-chroma-token: <CHROMA_API_KEY>`
- **Payload**:
  ```json
  {
    "query_embeddings": [<VECTOR_FLOAT_ARRAY>],
    "n_results": 15,
    "include": ["documents", "metadatas", "distances"]
  }
  ```
- **Similarity Scoring**: `simScore = 1.0 / (1.0 + max(0, distance))`

### D. Gemini 3.6 Flash Grounded Answer Generation
- **URL**: `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=<GEMINI_API_KEY>`
- **Headers**: `Content-Type: application/json`
- **System Instruction**:
  > You are MeghaRag, an expert AI assistant providing strictly grounded answers based ONLY on the provided context.
  > 
  > Strict Guidelines:
  > 1. Answer the query using ONLY facts directly stated in the provided context.
  > 2. If context lacks sufficient information, state: "I couldn't find sufficient information in the uploaded documents to answer your question."
  > 3. Do NOT extrapolate or assume facts.
  > 4. Whenever citing facts, include bracketed source numbers like [SOURCE X] where X matches the given context block ID.
- **Payload Structure**:
  ```json
  {
    "system_instruction": {
      "parts": [{"text": "<SYSTEM_PROMPT>"}]
    },
    "contents": [
      {
        "parts": [
          {
            "text": "--- RETRIEVED DOCUMENT CONTEXT ---\n<CONTEXT_BUFFER>\n\n--- USER QUESTION ---\n<USER_QUERY>\n\n--- GROUNDED ANSWER ---"
          }
        ]
      }
    ],
    "generationConfig": {
      "temperature": 0.1,
      "maxOutputTokens": 1000
    }
  }
  ```

---

## 3. Data Models & Service Contract

- **`Citation`**: `sourceId`, `fileName`, `pageNumber`, `section`, `snippet`
- **`RAGResponse`**: `answer`, `citations`, `confidenceScore`, `isGrounded`
- **Smart Citation Filtering**: Parse answer text using Regex `r'\[(?:SOURCE\s*)?(\d+)\]'` to match and return ONLY citations explicitly referenced in the response.

---

## 4. Implementation Location Standard
- Service implementation: `lib/services/megha_rag_service.dart` (or `lib/features/soil_analysis/services/megha_rag_service.dart`)
- UI Chat Component: `lib/views/chat_screen.dart` or integration into `MeghaAiChatScreen`.
