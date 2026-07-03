/*
===========================================================
AUTH
===========================================================
*/

----------------------------------------------------------
-- ROLE
----------------------------------------------------------

CREATE TABLE role
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(50) UNIQUE NOT NULL,

    name VARCHAR(100) NOT NULL,

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    deleted_at TIMESTAMPTZ,

    version INT DEFAULT 1
);

----------------------------------------------------------
-- PERMISSION
----------------------------------------------------------

CREATE TABLE permission
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(100) UNIQUE NOT NULL,

    module VARCHAR(100),

    action VARCHAR(50),

    description TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    version INT DEFAULT 1
);

----------------------------------------------------------
-- ROLE PERMISSION
----------------------------------------------------------

CREATE TABLE role_permission
(
    role_id UUID NOT NULL,

    permission_id UUID NOT NULL,

    PRIMARY KEY(role_id,permission_id),

    CONSTRAINT fk_role_permission_role
        FOREIGN KEY(role_id)
        REFERENCES role(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_role_permission_permission
        FOREIGN KEY(permission_id)
        REFERENCES permission(id)
        ON DELETE CASCADE
);

----------------------------------------------------------
-- USER
----------------------------------------------------------

CREATE TABLE app_user
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    username VARCHAR(50) UNIQUE NOT NULL,

    email CITEXT UNIQUE,

    phone VARCHAR(20) UNIQUE,

    password_hash TEXT NOT NULL,

    full_name VARCHAR(255),

    avatar TEXT,

    status user_status DEFAULT 'ACTIVE',

    last_login_at TIMESTAMPTZ,

    login_failed_count INT DEFAULT 0,

    email_verified BOOLEAN DEFAULT FALSE,

    phone_verified BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    deleted_at TIMESTAMPTZ,

    version INT DEFAULT 1
);

----------------------------------------------------------
-- USER ROLE
----------------------------------------------------------

CREATE TABLE user_role
(
    user_id UUID,

    role_id UUID,

    PRIMARY KEY(user_id,role_id),

    FOREIGN KEY(user_id)
        REFERENCES app_user(id)
        ON DELETE CASCADE,

    FOREIGN KEY(role_id)
        REFERENCES role(id)
        ON DELETE CASCADE
);

----------------------------------------------------------
-- REFRESH TOKEN
----------------------------------------------------------

CREATE TABLE refresh_token
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL,

    token TEXT NOT NULL,

    expired_at TIMESTAMPTZ NOT NULL,

    revoked BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_refresh_user
        FOREIGN KEY(user_id)
        REFERENCES app_user(id)
);

----------------------------------------------------------
-- LOGIN HISTORY
----------------------------------------------------------

CREATE TABLE login_history
(
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID,

    ip_address VARCHAR(50),

    user_agent TEXT,

    success BOOLEAN,

    login_at TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(user_id)
        REFERENCES app_user(id)
);

----------------------------------------------------------
-- INDEX
----------------------------------------------------------

CREATE INDEX idx_user_username
ON app_user(username);

CREATE INDEX idx_user_email
ON app_user(email);

CREATE INDEX idx_user_phone
ON app_user(phone);

CREATE INDEX idx_login_user
ON login_history(user_id);

CREATE INDEX idx_refresh_user
ON refresh_token(user_id);

----------------------------------------------------------
-- TRIGGER
----------------------------------------------------------

CREATE TRIGGER trg_role_update
BEFORE UPDATE
ON role
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_permission_update
BEFORE UPDATE
ON permission
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_user_update
BEFORE UPDATE
ON app_user
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();