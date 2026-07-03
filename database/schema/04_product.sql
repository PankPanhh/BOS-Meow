/*
===========================================================
Beverage Operating System
04_product.sql
Part A
Product Catalog
===========================================================
*/

------------------------------------------------------------
-- PRODUCT CATEGORY
------------------------------------------------------------

CREATE TABLE product_category
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    parent_id           UUID,

    category_code       VARCHAR(50) NOT NULL UNIQUE,

    category_name       VARCHAR(255) NOT NULL,

    slug                VARCHAR(255) UNIQUE,

    image_url           TEXT,

    description         TEXT,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    deleted_at          TIMESTAMPTZ,

    version             INT DEFAULT 1,

    CONSTRAINT fk_product_category_parent
        FOREIGN KEY(parent_id)
        REFERENCES product_category(id)
);

CREATE INDEX idx_product_category_parent
ON product_category(parent_id);

CREATE INDEX idx_product_category_name
ON product_category(category_name);

------------------------------------------------------------
-- PRODUCT TAG
------------------------------------------------------------

CREATE TABLE tag
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    tag_code            VARCHAR(50) UNIQUE NOT NULL,

    tag_name            VARCHAR(100) NOT NULL,

    color               VARCHAR(20),

    icon                VARCHAR(100),

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- PRODUCT
------------------------------------------------------------

CREATE TABLE product
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_id             UUID NOT NULL,

    product_code            VARCHAR(50) UNIQUE NOT NULL,

    product_name            VARCHAR(255) NOT NULL,

    slug                    VARCHAR(255) UNIQUE,

    short_description       TEXT,

    description             TEXT,

    thumbnail               TEXT,

    qr_code                 TEXT,

    barcode                 VARCHAR(100),

    seo_title               VARCHAR(255),

    seo_keyword             TEXT,

    seo_description         TEXT,

    is_active               BOOLEAN DEFAULT TRUE,

    is_featured             BOOLEAN DEFAULT FALSE,

    allow_note              BOOLEAN DEFAULT TRUE,

    display_order           INT DEFAULT 0,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    deleted_at              TIMESTAMPTZ,

    version                 INT DEFAULT 1,

    CONSTRAINT fk_product_category
        FOREIGN KEY(category_id)
        REFERENCES product_category(id)
);

CREATE INDEX idx_product_category
ON product(category_id);

CREATE INDEX idx_product_name
ON product(product_name);

CREATE INDEX idx_product_slug
ON product(slug);

------------------------------------------------------------
-- PRODUCT IMAGE
------------------------------------------------------------

CREATE TABLE product_image
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id          UUID NOT NULL,

    image_url           TEXT NOT NULL,

    is_thumbnail        BOOLEAN DEFAULT FALSE,

    display_order       INT DEFAULT 0,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_product_image_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_product_image_product
ON product_image(product_id);

------------------------------------------------------------
-- PRODUCT TAG MAPPING
------------------------------------------------------------

CREATE TABLE product_tag
(
    product_id      UUID,

    tag_id          UUID,

    created_at      TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY(product_id,tag_id),

    CONSTRAINT fk_product_tag_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_product_tag_tag
        FOREIGN KEY(tag_id)
        REFERENCES tag(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT SIZE
------------------------------------------------------------

CREATE TABLE product_size
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    size_code           VARCHAR(20) UNIQUE NOT NULL,

    size_name           VARCHAR(50) NOT NULL,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- PRODUCT VARIANT
------------------------------------------------------------

CREATE TABLE product_variant
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id              UUID NOT NULL,

    size_id                 UUID NOT NULL,

    sku                     VARCHAR(100) UNIQUE,

    barcode                 VARCHAR(100),

    selling_price           NUMERIC(18,2) NOT NULL,

    compare_price           NUMERIC(18,2),

    is_default              BOOLEAN DEFAULT FALSE,

    is_active               BOOLEAN DEFAULT TRUE,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    version                 INT DEFAULT 1,

    CONSTRAINT fk_variant_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_variant_size
        FOREIGN KEY(size_id)
        REFERENCES product_size(id),

    CONSTRAINT uq_product_size
        UNIQUE(product_id,size_id)
);

CREATE INDEX idx_variant_product
ON product_variant(product_id);

CREATE INDEX idx_variant_size
ON product_variant(size_id);

CREATE INDEX idx_variant_price
ON product_variant(selling_price);

------------------------------------------------------------
-- PRICE HISTORY
------------------------------------------------------------

CREATE TABLE product_price_history
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    variant_id          UUID NOT NULL,

    old_price           NUMERIC(18,2),

    new_price           NUMERIC(18,2),

    effective_from      TIMESTAMPTZ DEFAULT NOW(),

    effective_to        TIMESTAMPTZ,

    changed_by          UUID,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_price_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
);

CREATE INDEX idx_price_history_variant
ON product_price_history(variant_id);

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_product_category_update
BEFORE UPDATE
ON product_category
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_product_update
BEFORE UPDATE
ON product
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_variant_update
BEFORE UPDATE
ON product_variant
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
04_product.sql
Part B
Modifier - Topping - Combo - Menu
===========================================================
*/

------------------------------------------------------------
-- MODIFIER GROUP
------------------------------------------------------------

CREATE TABLE modifier_group
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    group_code          VARCHAR(50) UNIQUE NOT NULL,

    group_name          VARCHAR(150) NOT NULL,

    description         TEXT,

    min_select          INT DEFAULT 0,

    max_select          INT DEFAULT 1,

    is_required         BOOLEAN DEFAULT FALSE,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

CREATE INDEX idx_modifier_group_name
ON modifier_group(group_name);

------------------------------------------------------------
-- MODIFIER OPTION
------------------------------------------------------------

CREATE TABLE modifier_option
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    group_id            UUID NOT NULL,

    option_code         VARCHAR(50) UNIQUE NOT NULL,

    option_name         VARCHAR(150) NOT NULL,

    extra_price         NUMERIC(18,2) DEFAULT 0,

    display_order       INT DEFAULT 0,

    is_default          BOOLEAN DEFAULT FALSE,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1,

    CONSTRAINT fk_modifier_option_group
        FOREIGN KEY(group_id)
        REFERENCES modifier_group(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_modifier_option_group
ON modifier_option(group_id);

------------------------------------------------------------
-- PRODUCT MODIFIER GROUP
------------------------------------------------------------

CREATE TABLE product_modifier_group
(
    product_id          UUID,

    modifier_group_id   UUID,

    PRIMARY KEY(product_id, modifier_group_id),

    CONSTRAINT fk_pmg_product
        FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_pmg_group
        FOREIGN KEY(modifier_group_id)
        REFERENCES modifier_group(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- TOPPING CATEGORY
------------------------------------------------------------

CREATE TABLE topping_category
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_code       VARCHAR(50) UNIQUE NOT NULL,

    category_name       VARCHAR(150) NOT NULL,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- TOPPING
------------------------------------------------------------

CREATE TABLE topping
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_id         UUID NOT NULL,

    topping_code        VARCHAR(50) UNIQUE NOT NULL,

    topping_name        VARCHAR(150) NOT NULL,

    selling_price       NUMERIC(18,2) DEFAULT 0,

    image_url           TEXT,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1,

    CONSTRAINT fk_topping_category
        FOREIGN KEY(category_id)
        REFERENCES topping_category(id)
);

CREATE INDEX idx_topping_category
ON topping(category_id);

------------------------------------------------------------
-- PRODUCT VARIANT TOPPING
------------------------------------------------------------

CREATE TABLE product_variant_topping
(
    variant_id          UUID,

    topping_id          UUID,

    is_default          BOOLEAN DEFAULT FALSE,

    max_quantity        INT DEFAULT 1,

    PRIMARY KEY(variant_id, topping_id),

    CONSTRAINT fk_variant_topping_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_variant_topping_topping
        FOREIGN KEY(topping_id)
        REFERENCES topping(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- COMBO
------------------------------------------------------------

CREATE TABLE combo
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    combo_code          VARCHAR(50) UNIQUE NOT NULL,

    combo_name          VARCHAR(255) NOT NULL,

    description         TEXT,

    selling_price       NUMERIC(18,2) NOT NULL,

    image_url           TEXT,

    start_date          DATE,

    end_date            DATE,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- COMBO ITEM
------------------------------------------------------------

CREATE TABLE combo_item
(
    combo_id            UUID,

    variant_id          UUID,

    quantity            NUMERIC(10,2) DEFAULT 1,

    PRIMARY KEY(combo_id, variant_id),

    CONSTRAINT fk_combo_item_combo
        FOREIGN KEY(combo_id)
        REFERENCES combo(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_combo_item_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
);

------------------------------------------------------------
-- MENU
------------------------------------------------------------

CREATE TABLE menu
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    menu_code           VARCHAR(50) UNIQUE NOT NULL,

    menu_name           VARCHAR(150) NOT NULL,

    description         TEXT,

    start_time          TIME,

    end_time            TIME,

    is_default          BOOLEAN DEFAULT FALSE,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- MENU CATEGORY
------------------------------------------------------------

CREATE TABLE menu_category
(
    menu_id             UUID,

    category_id         UUID,

    display_order       INT DEFAULT 0,

    PRIMARY KEY(menu_id, category_id),

    CONSTRAINT fk_menu_category_menu
        FOREIGN KEY(menu_id)
        REFERENCES menu(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_menu_category_product_category
        FOREIGN KEY(category_id)
        REFERENCES product_category(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- MENU PRODUCT
------------------------------------------------------------

CREATE TABLE menu_product
(
    menu_id             UUID,

    variant_id          UUID,

    display_order       INT DEFAULT 0,

    PRIMARY KEY(menu_id, variant_id),

    CONSTRAINT fk_menu_product_menu
        FOREIGN KEY(menu_id)
        REFERENCES menu(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_menu_product_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT AVAILABILITY
------------------------------------------------------------

CREATE TABLE product_availability
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    variant_id          UUID NOT NULL,

    day_of_week         SMALLINT NOT NULL CHECK(day_of_week BETWEEN 0 AND 6),

    start_time          TIME NOT NULL,

    end_time            TIME NOT NULL,

    is_available        BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_product_availability_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_product_availability_variant
ON product_availability(variant_id);

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_modifier_group_update
BEFORE UPDATE
ON modifier_group
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_modifier_option_update
BEFORE UPDATE
ON modifier_option
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_topping_category_update
BEFORE UPDATE
ON topping_category
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_topping_update
BEFORE UPDATE
ON topping
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_combo_update
BEFORE UPDATE
ON combo
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_menu_update
BEFORE UPDATE
ON menu
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

/*
===========================================================
Beverage Operating System
04_product.sql
Part C
Enterprise Extension
===========================================================
*/

------------------------------------------------------------
-- ATTRIBUTE
------------------------------------------------------------

CREATE TABLE product_attribute
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    attribute_code      VARCHAR(50) UNIQUE NOT NULL,

    attribute_name      VARCHAR(100) NOT NULL,

    description         TEXT,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- ATTRIBUTE VALUE
------------------------------------------------------------

CREATE TABLE product_attribute_value
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    attribute_id        UUID NOT NULL,

    value_name          VARCHAR(100) NOT NULL,

    display_order       INT DEFAULT 0,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_attribute_value
        FOREIGN KEY(attribute_id)
        REFERENCES product_attribute(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT ATTRIBUTE
------------------------------------------------------------

CREATE TABLE product_variant_attribute
(
    variant_id          UUID,

    attribute_value_id  UUID,

    PRIMARY KEY
    (
        variant_id,
        attribute_value_id
    ),

    CONSTRAINT fk_pva_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_pva_attribute
        FOREIGN KEY(attribute_value_id)
        REFERENCES product_attribute_value(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRICE LIST
------------------------------------------------------------

CREATE TABLE price_list
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    price_code          VARCHAR(50) UNIQUE NOT NULL,

    price_name          VARCHAR(150) NOT NULL,

    description         TEXT,

    is_default          BOOLEAN DEFAULT FALSE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

------------------------------------------------------------
-- PRICE LIST ITEM
------------------------------------------------------------

CREATE TABLE price_list_item
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    price_list_id       UUID NOT NULL,

    variant_id          UUID NOT NULL,

    selling_price       NUMERIC(18,2) NOT NULL,

    start_date          TIMESTAMPTZ,

    end_date            TIMESTAMPTZ,

    CONSTRAINT fk_price_list
        FOREIGN KEY(price_list_id)
        REFERENCES price_list(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_price_variant
        FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_price_list_item_variant
ON price_list_item(variant_id);

------------------------------------------------------------
-- DISPLAY CHANNEL
------------------------------------------------------------

CREATE TABLE display_channel
(
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    channel_code    VARCHAR(50) UNIQUE NOT NULL,

    channel_name    VARCHAR(100) NOT NULL
);

------------------------------------------------------------
-- PRODUCT CHANNEL
------------------------------------------------------------

CREATE TABLE product_channel
(
    variant_id      UUID,

    channel_id      UUID,

    PRIMARY KEY
    (
        variant_id,
        channel_id
    ),

    FOREIGN KEY(variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE,

    FOREIGN KEY(channel_id)
        REFERENCES display_channel(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT RECOMMENDATION
------------------------------------------------------------

CREATE TABLE product_recommendation
(
    product_id              UUID,

    recommend_product_id    UUID,

    priority                INT DEFAULT 1,

    PRIMARY KEY
    (
        product_id,
        recommend_product_id
    ),

    FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE,

    FOREIGN KEY(recommend_product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT SEO
------------------------------------------------------------

CREATE TABLE product_seo
(
    product_id          UUID PRIMARY KEY,

    canonical_url       TEXT,

    meta_title          VARCHAR(255),

    meta_keyword        TEXT,

    meta_description    TEXT,

    open_graph_image    TEXT,

    FOREIGN KEY(product_id)
        REFERENCES product(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- PRODUCT STATUS HISTORY
------------------------------------------------------------

CREATE TABLE product_status_history
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    product_id          UUID,

    old_status          BOOLEAN,

    new_status          BOOLEAN,

    changed_by          UUID,

    changed_at          TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(product_id)
        REFERENCES product(id)
);

------------------------------------------------------------
-- INDEX
------------------------------------------------------------

CREATE INDEX idx_product_recommendation
ON product_recommendation(product_id);

CREATE INDEX idx_product_channel
ON product_channel(variant_id);

------------------------------------------------------------
-- TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_attribute_update
BEFORE UPDATE
ON product_attribute
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_price_list_update
BEFORE UPDATE
ON price_list
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

------------------------------------------------------------
-- DEFAULT DATA
------------------------------------------------------------

INSERT INTO display_channel
(channel_code, channel_name)
VALUES
('WEBSITE','Website'),
('POS','POS'),
('QR','QR Ordering'),
('MOBILE','Mobile App')
ON CONFLICT DO NOTHING;

INSERT INTO price_list
(price_code,price_name,is_default)
VALUES
('DEFAULT','Default Price',TRUE),
('PROMOTION','Promotion',FALSE),
('MEMBER','Member',FALSE)
ON CONFLICT DO NOTHING;