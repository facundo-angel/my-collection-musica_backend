DROP TABLE IF EXISTS plays, activity, collection_tracks, collections, reviews,
  library_items, user_genres, users, tracks, album_genres, albums, genres, artists CASCADE;

-- ===== Catálogo (datos de Deezer; solo lo que algún usuario usó) =====

CREATE TABLE artists (
  id BIGINT PRIMARY KEY,
  name TEXT NOT NULL,
  picture_url TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE genres (
  id INTEGER PRIMARY KEY,
  name VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE albums (
  id BIGINT PRIMARY KEY,
  title TEXT NOT NULL,
  artist_id BIGINT NOT NULL REFERENCES artists(id),
  cover_url TEXT,
  release_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deezer asigna los géneros al álbum, no a la canción
CREATE TABLE album_genres (
  album_id BIGINT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  genre_id INTEGER NOT NULL REFERENCES genres(id),
  PRIMARY KEY (album_id, genre_id)
);

-- El preview no se guarda porque Deezer lo hace vencer a las pocas horas
CREATE TABLE tracks (
  id BIGINT PRIMARY KEY,
  title TEXT NOT NULL,
  artist_id BIGINT NOT NULL REFERENCES artists(id),
  album_id BIGINT NOT NULL REFERENCES albums(id),
  duration_sec INTEGER NOT NULL CHECK (duration_sec > 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===== Usuarios =====

CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(30) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name VARCHAR(60),
  bio VARCHAR(300),
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_genres (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  genre_id INTEGER NOT NULL REFERENCES genres(id),
  PRIMARY KEY (user_id, genre_id)
);

-- ===== Datos personales =====

CREATE TABLE library_items (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  track_id BIGINT NOT NULL REFERENCES tracks(id),
  status VARCHAR(20) NOT NULL DEFAULT 'quiero_escuchar'
    CHECK (status IN ('quiero_escuchar', 'escuchando', 'escuchado', 'favorito')),
  is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
  rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, track_id)
);

CREATE TABLE reviews (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  track_id BIGINT NOT NULL REFERENCES tracks(id),
  body VARCHAR(1000) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, track_id)
);

CREATE TABLE collections (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(80) NOT NULL,
  description VARCHAR(300),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, name)
);

CREATE TABLE collection_tracks (
  collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  track_id BIGINT NOT NULL REFERENCES tracks(id),
  added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (collection_id, track_id)
);

-- Si se borra una colección, la actividad conserva el nombre en detail
CREATE TABLE activity (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(30) NOT NULL CHECK (type IN (
    'agrego_cancion', 'quito_cancion', 'cambio_estado', 'marco_favorito',
    'desmarco_favorito', 'puntuo', 'reseno', 'edito_resena', 'borro_resena',
    'creo_coleccion', 'borro_coleccion', 'agrego_a_coleccion', 'quito_de_coleccion'
  )),
  track_id BIGINT REFERENCES tracks(id),
  collection_id INTEGER REFERENCES collections(id) ON DELETE SET NULL,
  detail TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE plays (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  track_id BIGINT NOT NULL REFERENCES tracks(id),
  seconds SMALLINT NOT NULL CHECK (seconds > 0),
  played_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para las consultas más frecuentes
CREATE INDEX idx_tracks_artist ON tracks(artist_id);
CREATE INDEX idx_tracks_album ON tracks(album_id);
CREATE INDEX idx_collections_user ON collections(user_id);
CREATE INDEX idx_activity_user_date ON activity(user_id, created_at DESC);
CREATE INDEX idx_plays_user_date ON plays(user_id, played_at);