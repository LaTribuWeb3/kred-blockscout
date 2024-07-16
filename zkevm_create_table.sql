-- Create table polygon_zkevm_lifecycle_l1_transactions
CREATE TABLE polygon_zkevm_lifecycle_l1_transactions (
    id INTEGER NOT NULL PRIMARY KEY,
    hash BYTEA NOT NULL,
    is_verify BOOLEAN NOT NULL,
    inserted_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

-- Create unique index on hash in polygon_zkevm_lifecycle_l1_transactions
CREATE UNIQUE INDEX polygon_zkevm_lifecycle_l1_transactions_hash_index ON polygon_zkevm_lifecycle_l1_transactions(hash);

-- Create table polygon_zkevm_transaction_batches
CREATE TABLE polygon_zkevm_transaction_batches (
    number INTEGER NOT NULL PRIMARY KEY,
    timestamp TIMESTAMP WITHOUT TIME ZONE,
    l2_transactions_count INTEGER NOT NULL,
    global_exit_root BYTEA NOT NULL,
    acc_input_hash BYTEA NOT NULL,
    state_root BYTEA NOT NULL,
    sequence_id INTEGER,
    verify_id INTEGER,
    inserted_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_sequence_id FOREIGN KEY(sequence_id) REFERENCES polygon_zkevm_lifecycle_l1_transactions(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_verify_id FOREIGN KEY(verify_id) REFERENCES polygon_zkevm_lifecycle_l1_transactions(id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Create table polygon_zkevm_batch_l2_transactions
CREATE TABLE polygon_zkevm_batch_l2_transactions (
    batch_number INTEGER NOT NULL,
    hash BYTEA NOT NULL PRIMARY KEY,
    inserted_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT fk_batch_number FOREIGN KEY(batch_number) REFERENCES polygon_zkevm_transaction_batches(number) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Create index on batch_number in polygon_zkevm_batch_l2_transactions
CREATE INDEX polygon_zkevm_batch_l2_transactions_batch_number_index ON polygon_zkevm_batch_l2_transactions(batch_number);

-- Create table polygon_zkevm_bridge_l1_tokens
CREATE TABLE polygon_zkevm_bridge_l1_tokens (
    id SERIAL PRIMARY KEY,
    address BYTEA NOT NULL,
    decimals SMALLINT DEFAULT NULL,
    symbol VARCHAR(16) DEFAULT NULL,
    inserted_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

-- Create unique index on address in polygon_zkevm_bridge_l1_tokens
CREATE UNIQUE INDEX polygon_zkevm_bridge_l1_tokens_address_index ON polygon_zkevm_bridge_l1_tokens(address);

-- Create type polygon_zkevm_bridge_op_type
CREATE TYPE polygon_zkevm_bridge_op_type AS ENUM ('deposit', 'withdrawal');

-- Create table polygon_zkevm_bridge
CREATE TABLE polygon_zkevm_bridge (
    type polygon_zkevm_bridge_op_type NOT NULL,
    index INTEGER NOT NULL,
    l1_transaction_hash BYTEA,
    l2_transaction_hash BYTEA,
    l1_token_id INTEGER,
    l1_token_address BYTEA,
    l2_token_address BYTEA,
    amount NUMERIC(100) NOT NULL,
    block_number BIGINT,
    block_timestamp TIMESTAMP WITHOUT TIME ZONE,
    inserted_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (type, index),
    CONSTRAINT fk_l1_token_id FOREIGN KEY(l1_token_id) REFERENCES polygon_zkevm_bridge_l1_tokens(id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Create index on l1_token_address in polygon_zkevm_bridge
CREATE INDEX polygon_zkevm_bridge_l1_token_address_index ON polygon_zkevm_bridge(l1_token_address);