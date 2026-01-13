# pgvector

## Overview

pgvector is a PostgreSQL extension for vector similarity search, used for embeddings from LLMs. This enables semantic search, recommendations, and RAG (Retrieval Augmented Generation) applications.

## Setup

### Enable Extension

```python
# migrations/versions/001_enable_pgvector.py
def upgrade() -> None:
    op.execute('CREATE EXTENSION IF NOT EXISTS vector')


def downgrade() -> None:
    op.execute('DROP EXTENSION IF EXISTS vector')
```

### Install Python Package

```bash
uv add pgvector
```

## Model Definition

### SQLAlchemy Model with Vector Column

```python
# src/models/document.py
from uuid import UUID
from sqlalchemy import String, Text, Index
from sqlalchemy.orm import Mapped, mapped_column
from pgvector.sqlalchemy import Vector

from src.models.base import Base, UUIDPrimaryKeyMixin, TimestampMixin


class Document(Base, UUIDPrimaryKeyMixin, TimestampMixin):
    __tablename__ = "documents"

    title: Mapped[str] = mapped_column(String(500), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)

    # Vector column for embeddings
    # 1536 dimensions for OpenAI text-embedding-3-small
    # 3072 dimensions for text-embedding-3-large
    embedding: Mapped[list[float] | None] = mapped_column(
        Vector(1536),
        nullable=True,
    )

    # Indexes for vector similarity search
    __table_args__ = (
        # IVFFlat index - good for medium datasets (up to ~1M vectors)
        Index(
            "ix_documents_embedding_ivfflat",
            "embedding",
            postgresql_using="ivfflat",
            postgresql_with={"lists": 100},
            postgresql_ops={"embedding": "vector_cosine_ops"},
        ),
    )
```

### Migration for Vector Column

```python
# migrations/versions/002_add_document_embeddings.py
from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector

revision = "002"
down_revision = "001"


def upgrade() -> None:
    op.create_table(
        "documents",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("embedding", Vector(1536), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.PrimaryKeyConstraint("id"),
    )

    # Create IVFFlat index after table has data
    # For empty table, create index immediately
    op.execute("""
        CREATE INDEX ix_documents_embedding_ivfflat
        ON documents
        USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 100)
    """)


def downgrade() -> None:
    op.drop_table("documents")
```

## Index Types

### IVFFlat (Inverted File Flat)

Best for most use cases up to ~1M vectors:

```python
Index(
    "ix_embedding_ivfflat",
    "embedding",
    postgresql_using="ivfflat",
    postgresql_with={"lists": 100},  # Adjust based on dataset size
    postgresql_ops={"embedding": "vector_cosine_ops"},
)
```

**Guidelines for `lists` parameter:**

- Up to 1M rows: `lists = rows / 1000`
- Over 1M rows: `lists = sqrt(rows)`

### HNSW (Hierarchical Navigable Small World)

Better recall, more memory, good for high-precision needs:

```python
Index(
    "ix_embedding_hnsw",
    "embedding",
    postgresql_using="hnsw",
    postgresql_with={"m": 16, "ef_construction": 64},
    postgresql_ops={"embedding": "vector_cosine_ops"},
)
```

## Distance Functions

| Function | Use Case | Operator |
|----------|----------|----------|
| Cosine distance | Normalized embeddings (most common) | `<=>` |
| L2 (Euclidean) | Unnormalized embeddings | `<->` |
| Inner product | When using dot product similarity | `<#>` |

## Querying

### Basic Similarity Search

```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pgvector.sqlalchemy import Vector


async def search_similar_documents(
    db: AsyncSession,
    query_embedding: list[float],
    limit: int = 10,
) -> list[Document]:
    """Find documents similar to query embedding."""
    result = await db.execute(
        select(Document)
        .order_by(Document.embedding.cosine_distance(query_embedding))
        .limit(limit)
    )
    return list(result.scalars().all())
```

### Search with Distance Threshold

```python
async def search_with_threshold(
    db: AsyncSession,
    query_embedding: list[float],
    max_distance: float = 0.3,
    limit: int = 10,
) -> list[tuple[Document, float]]:
    """Find similar documents within distance threshold."""
    distance = Document.embedding.cosine_distance(query_embedding)

    result = await db.execute(
        select(Document, distance.label("distance"))
        .where(distance < max_distance)
        .order_by(distance)
        .limit(limit)
    )

    return [(row.Document, row.distance) for row in result.all()]
```

### Search with Filters

```python
async def search_in_category(
    db: AsyncSession,
    query_embedding: list[float],
    category_id: UUID,
    limit: int = 10,
) -> list[Document]:
    """Search within a specific category."""
    result = await db.execute(
        select(Document)
        .where(Document.category_id == category_id)
        .order_by(Document.embedding.cosine_distance(query_embedding))
        .limit(limit)
    )
    return list(result.scalars().all())
```

### Hybrid Search (Vector + Full-Text)

```python
from sqlalchemy import func, text


async def hybrid_search(
    db: AsyncSession,
    query_text: str,
    query_embedding: list[float],
    limit: int = 10,
    vector_weight: float = 0.7,
) -> list[Document]:
    """Combine vector similarity with full-text search."""
    # Vector similarity score (convert distance to similarity)
    vector_score = 1 - Document.embedding.cosine_distance(query_embedding)

    # Full-text search score
    text_score = func.ts_rank(
        Document.search_vector,
        func.plainto_tsquery("english", query_text),
    )

    # Combined score
    combined_score = (
        vector_weight * vector_score +
        (1 - vector_weight) * text_score
    ).label("score")

    result = await db.execute(
        select(Document, combined_score)
        .where(
            Document.search_vector.match(query_text)  # Filter by text match
        )
        .order_by(combined_score.desc())
        .limit(limit)
    )

    return [row.Document for row in result.all()]
```

## Generating Embeddings

### OpenAI Embeddings

```python
# src/services/embedding_service.py
import httpx
from src.core.config import get_settings

settings = get_settings()


class EmbeddingService:
    def __init__(self, http_client: httpx.AsyncClient):
        self.client = http_client
        self.model = "text-embedding-3-small"

    async def get_embedding(self, text: str) -> list[float]:
        """Generate embedding for a single text."""
        response = await self.client.post(
            "https://api.openai.com/v1/embeddings",
            headers={"Authorization": f"Bearer {settings.openai_api_key}"},
            json={"input": text, "model": self.model},
        )
        response.raise_for_status()
        return response.json()["data"][0]["embedding"]

    async def get_embeddings_batch(
        self,
        texts: list[str],
    ) -> list[list[float]]:
        """Generate embeddings for multiple texts."""
        response = await self.client.post(
            "https://api.openai.com/v1/embeddings",
            headers={"Authorization": f"Bearer {settings.openai_api_key}"},
            json={"input": texts, "model": self.model},
        )
        response.raise_for_status()
        data = response.json()["data"]
        # Sort by index to maintain order
        sorted_data = sorted(data, key=lambda x: x["index"])
        return [item["embedding"] for item in sorted_data]
```

### Using with LiteLLM

```python
import litellm


async def get_embedding(text: str, model: str = "text-embedding-3-small") -> list[float]:
    """Generate embedding using LiteLLM."""
    response = await litellm.aembedding(model=model, input=[text])
    return response.data[0]["embedding"]
```

## Document Service Example

```python
# src/services/document_service.py
from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import structlog

from src.models.document import Document
from src.schemas.document import DocumentCreate, DocumentSearchResult
from src.services.embedding_service import EmbeddingService
from src.core.exceptions import NotFoundError

logger = structlog.get_logger()


class DocumentService:
    def __init__(
        self,
        db: AsyncSession,
        embedding_service: EmbeddingService,
    ):
        self.db = db
        self.embedding_service = embedding_service

    async def create(self, data: DocumentCreate) -> Document:
        """Create document and generate embedding."""
        # Generate embedding from content
        embedding = await self.embedding_service.get_embedding(
            f"{data.title}\n\n{data.content}"
        )

        document = Document(
            title=data.title,
            content=data.content,
            embedding=embedding,
        )
        self.db.add(document)
        await self.db.commit()
        await self.db.refresh(document)

        logger.info("document_created", document_id=str(document.id))
        return document

    async def search(
        self,
        query: str,
        limit: int = 10,
    ) -> list[DocumentSearchResult]:
        """Search documents by semantic similarity."""
        # Generate query embedding
        query_embedding = await self.embedding_service.get_embedding(query)

        # Search similar documents
        distance = Document.embedding.cosine_distance(query_embedding)
        result = await self.db.execute(
            select(Document, distance.label("distance"))
            .where(Document.embedding.isnot(None))
            .order_by(distance)
            .limit(limit)
        )

        return [
            DocumentSearchResult(
                id=row.Document.id,
                title=row.Document.title,
                content=row.Document.content[:500],  # Truncate for preview
                similarity=1 - row.distance,  # Convert distance to similarity
            )
            for row in result.all()
        ]

    async def backfill_embeddings(self, batch_size: int = 100) -> int:
        """Generate embeddings for documents missing them."""
        count = 0

        while True:
            # Get batch of documents without embeddings
            result = await self.db.execute(
                select(Document)
                .where(Document.embedding.is_(None))
                .limit(batch_size)
            )
            documents = list(result.scalars().all())

            if not documents:
                break

            # Generate embeddings in batch
            texts = [f"{d.title}\n\n{d.content}" for d in documents]
            embeddings = await self.embedding_service.get_embeddings_batch(texts)

            # Update documents
            for doc, embedding in zip(documents, embeddings):
                doc.embedding = embedding

            await self.db.commit()
            count += len(documents)
            logger.info("embeddings_backfilled", batch_count=len(documents), total=count)

        return count
```

## Performance Tuning

### Index Tuning

```sql
-- Increase probes for better recall (slower)
SET ivfflat.probes = 10;

-- Or set per-query
SELECT * FROM documents
ORDER BY embedding <=> '[...]'::vector
LIMIT 10;
SET LOCAL ivfflat.probes = 20;
```

### Build Index After Data Load

```python
def upgrade() -> None:
    # Create table without index
    op.create_table("documents", ...)

    # Load data here (or in separate migration)

    # Then create index (faster on existing data)
    op.execute("""
        CREATE INDEX CONCURRENTLY ix_documents_embedding
        ON documents USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 100)
    """)
```

### Memory Considerations

```sql
-- For HNSW, increase maintenance_work_mem during index creation
SET maintenance_work_mem = '2GB';
CREATE INDEX ...;
RESET maintenance_work_mem;
```

## Best Practices

### 1. Choose the Right Dimension

```python
# Match your embedding model's output dimension
# OpenAI text-embedding-3-small: 1536
# OpenAI text-embedding-3-large: 3072
# Cohere embed-english-v3: 1024

embedding: Mapped[list[float]] = mapped_column(Vector(1536))
```

### 2. Normalize Embeddings for Cosine Similarity

Most embedding APIs return normalized vectors, but verify:

```python
import numpy as np

def normalize(embedding: list[float]) -> list[float]:
    arr = np.array(embedding)
    return (arr / np.linalg.norm(arr)).tolist()
```

### 3. Use Appropriate Index Type

| Scenario | Index | Reason |
|----------|-------|--------|
| < 100K vectors | IVFFlat | Simpler, less memory |
| 100K - 1M vectors | IVFFlat or HNSW | Both work well |
| > 1M vectors | HNSW | Better scaling |
| High recall needed | HNSW | More accurate |
| Memory constrained | IVFFlat | Lower memory usage |

### 4. Batch Embedding Generation

```python
# Good - batch API calls
embeddings = await embedding_service.get_embeddings_batch(texts)

# Avoid - individual calls
for text in texts:
    embedding = await embedding_service.get_embedding(text)  # Slow!
```

### 5. Handle Missing Embeddings

```python
async def search(self, query: str) -> list[Document]:
    result = await self.db.execute(
        select(Document)
        .where(Document.embedding.isnot(None))  # Filter out nulls
        .order_by(Document.embedding.cosine_distance(query_embedding))
        .limit(10)
    )
    return list(result.scalars().all())
```
