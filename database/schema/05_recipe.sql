/*
===========================================================
Beverage Operating System
05_recipe.sql
Part A
Recipe Core
===========================================================
*/

------------------------------------------------------------
-- RECIPE
------------------------------------------------------------

CREATE TABLE recipe
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_code             VARCHAR(50) UNIQUE NOT NULL,

    recipe_name             VARCHAR(255) NOT NULL,

    product_variant_id      UUID NOT NULL,

    description             TEXT,

    is_active               BOOLEAN DEFAULT TRUE,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    deleted_at              TIMESTAMPTZ,

    version                 INT DEFAULT 1,

    CONSTRAINT fk_recipe_variant
        FOREIGN KEY(product_variant_id)
        REFERENCES product_variant(id)
        ON DELETE CASCADE
);

CREATE INDEX idx_recipe_variant
ON recipe(product_variant_id);

------------------------------------------------------------
-- RECIPE VERSION
------------------------------------------------------------

CREATE TABLE recipe_version
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_id               UUID NOT NULL,

    version_no              INT NOT NULL,

    version_name            VARCHAR(100),

    note                    TEXT,

    effective_from          TIMESTAMPTZ DEFAULT NOW(),

    effective_to            TIMESTAMPTZ,

    is_current              BOOLEAN DEFAULT FALSE,

    approved_by             UUID,

    approved_at             TIMESTAMPTZ,

    created_by              UUID,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    version                 INT DEFAULT 1,

    CONSTRAINT fk_recipe_version_recipe
        FOREIGN KEY(recipe_id)
        REFERENCES recipe(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_recipe_version_approved
        FOREIGN KEY(approved_by)
        REFERENCES app_user(id),

    CONSTRAINT fk_recipe_version_created
        FOREIGN KEY(created_by)
        REFERENCES app_user(id),

    CONSTRAINT uq_recipe_version
        UNIQUE(recipe_id, version_no)
);

CREATE INDEX idx_recipe_version_recipe
ON recipe_version(recipe_id);

CREATE INDEX idx_recipe_version_current
ON recipe_version(is_current);

------------------------------------------------------------
-- RECIPE STEP
------------------------------------------------------------

CREATE TABLE recipe_step
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    step_no                 INT NOT NULL,

    step_name               VARCHAR(255),

    instruction             TEXT NOT NULL,

    estimated_second        INT DEFAULT 0,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_step
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    CONSTRAINT uq_recipe_step
        UNIQUE(recipe_version_id, step_no)
);

CREATE INDEX idx_recipe_step_recipe
ON recipe_step(recipe_version_id);

------------------------------------------------------------
-- UNIT
------------------------------------------------------------

CREATE TABLE ingredient_unit
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    unit_code           VARCHAR(20) UNIQUE NOT NULL,

    unit_name           VARCHAR(100) NOT NULL,

    symbol              VARCHAR(20),

    decimal_place       SMALLINT DEFAULT 2,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW()
);

------------------------------------------------------------
-- RECIPE INGREDIENT
------------------------------------------------------------

CREATE TABLE recipe_ingredient
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    ingredient_id           UUID NOT NULL,

    unit_id                 UUID NOT NULL,

    quantity                NUMERIC(18,4) NOT NULL,

    wastage_percent         NUMERIC(5,2) DEFAULT 0,

    display_order           INT DEFAULT 0,

    note                    TEXT,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_ingredient_recipe
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_recipe_ingredient_unit
        FOREIGN KEY(unit_id)
        REFERENCES ingredient_unit(id)
);

CREATE INDEX idx_recipe_ingredient_recipe
ON recipe_ingredient(recipe_version_id);

------------------------------------------------------------
-- RECIPE EQUIPMENT
------------------------------------------------------------

CREATE TABLE recipe_equipment
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    equipment_name          VARCHAR(255),

    quantity                NUMERIC(10,2) DEFAULT 1,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_equipment
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- RECIPE NOTE
------------------------------------------------------------

CREATE TABLE recipe_note
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID NOT NULL,

    note_type               VARCHAR(50),

    note_content            TEXT,

    created_by              UUID,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT fk_recipe_note_recipe
        FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_recipe_note_user
        FOREIGN KEY(created_by)
        REFERENCES app_user(id)
);

------------------------------------------------------------
-- TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_recipe_update
BEFORE UPDATE
ON recipe
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_recipe_version_update
BEFORE UPDATE
ON recipe_version
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

------------------------------------------------------------
-- DEFAULT UNIT
------------------------------------------------------------

INSERT INTO ingredient_unit
(unit_code, unit_name, symbol)
VALUES
('G','Gram','g'),
('KG','Kilogram','kg'),
('ML','Milliliter','ml'),
('L','Liter','L'),
('PCS','Piece','pcs'),
('PACK','Pack','pack'),
('BOTTLE','Bottle','bottle'),
('CUP','Cup','cup')
ON CONFLICT DO NOTHING;

/*
===========================================================
Beverage Operating System
05_recipe.sql
Part B
Ingredient & Cost Engine
===========================================================
*/

------------------------------------------------------------
-- INGREDIENT CATEGORY
------------------------------------------------------------

CREATE TABLE ingredient_category
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_code       VARCHAR(50) UNIQUE NOT NULL,

    category_name       VARCHAR(150) NOT NULL,

    description         TEXT,

    display_order       INT DEFAULT 0,

    is_active           BOOLEAN DEFAULT TRUE,

    created_at          TIMESTAMPTZ DEFAULT NOW(),

    updated_at          TIMESTAMPTZ DEFAULT NOW(),

    version             INT DEFAULT 1
);

CREATE INDEX idx_ingredient_category_name
ON ingredient_category(category_name);

------------------------------------------------------------
-- INGREDIENT
------------------------------------------------------------

CREATE TABLE ingredient
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    category_id             UUID NOT NULL,

    ingredient_code         VARCHAR(50) UNIQUE NOT NULL,

    ingredient_name         VARCHAR(255) NOT NULL,

    unit_id                 UUID NOT NULL,

    description             TEXT,

    barcode                 VARCHAR(100),

    minimum_stock           NUMERIC(18,4) DEFAULT 0,

    maximum_stock           NUMERIC(18,4),

    reorder_point           NUMERIC(18,4) DEFAULT 0,

    shelf_life_day          INT,

    is_inventory            BOOLEAN DEFAULT TRUE,

    is_active               BOOLEAN DEFAULT TRUE,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    updated_at              TIMESTAMPTZ DEFAULT NOW(),

    deleted_at              TIMESTAMPTZ,

    version                 INT DEFAULT 1,

    CONSTRAINT fk_ingredient_category
        FOREIGN KEY(category_id)
        REFERENCES ingredient_category(id),

    CONSTRAINT fk_ingredient_unit
        FOREIGN KEY(unit_id)
        REFERENCES ingredient_unit(id)
);

CREATE INDEX idx_ingredient_code
ON ingredient(ingredient_code);

CREATE INDEX idx_ingredient_name
ON ingredient(ingredient_name);

------------------------------------------------------------
-- INGREDIENT SUPPLIER
------------------------------------------------------------

CREATE TABLE ingredient_supplier
(
    ingredient_id       UUID,

    supplier_id         UUID,

    priority            INT DEFAULT 1,

    is_default          BOOLEAN DEFAULT FALSE,

    PRIMARY KEY
    (
        ingredient_id,
        supplier_id
    ),

    FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- INGREDIENT PRICE HISTORY
------------------------------------------------------------

CREATE TABLE ingredient_price_history
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    ingredient_id           UUID NOT NULL,

    supplier_id             UUID,

    unit_price              NUMERIC(18,4) NOT NULL,

    effective_from          TIMESTAMPTZ DEFAULT NOW(),

    effective_to            TIMESTAMPTZ,

    note                    TEXT,

    created_at              TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_price_history_ingredient
ON ingredient_price_history(ingredient_id);

------------------------------------------------------------
-- RECIPE COST
------------------------------------------------------------

CREATE TABLE recipe_cost
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID UNIQUE NOT NULL,

    ingredient_cost         NUMERIC(18,4) DEFAULT 0,

    packaging_cost          NUMERIC(18,4) DEFAULT 0,

    labor_cost              NUMERIC(18,4) DEFAULT 0,

    overhead_cost           NUMERIC(18,4) DEFAULT 0,

    total_cost              NUMERIC(18,4) DEFAULT 0,

    calculated_at           TIMESTAMPTZ DEFAULT NOW(),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- RECIPE COST DETAIL
------------------------------------------------------------

CREATE TABLE recipe_cost_detail
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_cost_id          UUID NOT NULL,

    ingredient_id           UUID NOT NULL,

    quantity                NUMERIC(18,4),

    unit_cost               NUMERIC(18,4),

    total_cost              NUMERIC(18,4),

    FOREIGN KEY(recipe_cost_id)
        REFERENCES recipe_cost(id)
        ON DELETE CASCADE,

    FOREIGN KEY(ingredient_id)
        REFERENCES ingredient(id)
);

CREATE INDEX idx_recipe_cost_detail
ON recipe_cost_detail(recipe_cost_id);

------------------------------------------------------------
-- RECIPE YIELD
------------------------------------------------------------

CREATE TABLE recipe_yield
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID UNIQUE NOT NULL,

    yield_quantity          NUMERIC(18,4),

    yield_unit              VARCHAR(50),

    serving                 NUMERIC(18,4),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- RECIPE NUTRITION
------------------------------------------------------------

CREATE TABLE recipe_nutrition
(
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    recipe_version_id       UUID UNIQUE NOT NULL,

    calories                NUMERIC(10,2),

    carbohydrate            NUMERIC(10,2),

    protein                 NUMERIC(10,2),

    fat                     NUMERIC(10,2),

    sugar                   NUMERIC(10,2),

    sodium                  NUMERIC(10,2),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE
);

------------------------------------------------------------
-- ALLERGEN
------------------------------------------------------------

CREATE TABLE allergen
(
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    allergen_code       VARCHAR(50) UNIQUE,

    allergen_name       VARCHAR(150)
);

------------------------------------------------------------
-- RECIPE ALLERGEN
------------------------------------------------------------

CREATE TABLE recipe_allergen
(
    recipe_version_id   UUID,

    allergen_id         UUID,

    PRIMARY KEY
    (
        recipe_version_id,
        allergen_id
    ),

    FOREIGN KEY(recipe_version_id)
        REFERENCES recipe_version(id)
        ON DELETE CASCADE,

    FOREIGN KEY(allergen_id)
        REFERENCES allergen(id)
);

------------------------------------------------------------
-- COST CALCULATION FUNCTION
------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_recipe_cost
(
    p_recipe_version UUID
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS
$$
DECLARE

    v_total NUMERIC(18,4);

BEGIN

    SELECT
        COALESCE
        (
            SUM
            (
                ri.quantity *
                COALESCE
                (
                    (
                        SELECT unit_price
                        FROM ingredient_price_history iph
                        WHERE iph.ingredient_id = ri.ingredient_id
                        ORDER BY effective_from DESC
                        LIMIT 1
                    ),
                    0
                )
            ),
            0
        )
    INTO v_total
    FROM recipe_ingredient ri
    WHERE ri.recipe_version_id = p_recipe_version;

    RETURN v_total;

END;
$$;

------------------------------------------------------------
-- UPDATE TRIGGER
------------------------------------------------------------

CREATE TRIGGER trg_ingredient_category_update
BEFORE UPDATE
ON ingredient_category
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_ingredient_update
BEFORE UPDATE
ON ingredient
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();