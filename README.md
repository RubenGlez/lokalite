## Database Schema

### 1. Users

Table that stores information about users, including their credentials and roles.

- **Table: Users**
  - `user_id` (PK): Unique identifier for each user.
  - `name`: User's name.
  - `email`: User's email address, used for login.
  - `password_hash`: Hashed password for security.

### 2. Projects

Table that stores projects created by users. Each project can have multiple sheets for different translation needs.

- **Table: Projects**
  - `project_id` (PK): Unique identifier for each project.
  - `name`: Name of the project.
  - `description`: Brief description of the project.
  - `creation_date`: Date when the project was created.
  - `user_id` (FK): Identifier of the user who created the project.

### 3. Sheets

Each project can include multiple sheets. Each sheet corresponds to a specific translation need, such as different platforms or functionalities.

- **Table: Sheets**
  - `sheet_id` (PK): Unique identifier for each sheet.
  - `project_id` (FK): Foreign key that links to the Projects table.
  - `name`: Name of the sheet (e.g., Mobile, Web).
  - `source_language`: Source language code (e.g., "EN").

### 4. Copy

Table that stores the copy to be translated, linked to each sheet. Each piece of copy has an original version.

- **Table: Copy**
  - `copy_id` (PK): Unique identifier for each piece of copy.
  - `sheet_id` (FK): Foreign key that links to the Sheets table.
  - `copy_key`: Key or identifier used to reference the copy (used in the code or application).
  - `original_text`: Original text of the copy in the source language.

### 5. Target Languages

Table that stores the relationship between sheets and their target languages. This allows for managing multiple target languages for each sheet.

- **Table: Target Languages**
  - `target_language_id` (PK): Unique identifier for each target language relation.
  - `sheet_id` (FK): Foreign key that links to the Sheets table.
  - `language_code`: Language code (e.g., "ES", "FR").

### 6. Translations

Table that stores translations for each copy in various target languages.

- **Table: Translations**
  - `translation_id` (PK): Unique identifier for each translation.
  - `copy_id` (FK): Foreign key that links to the Copy table.
  - `language_code`: Language code of the translation (corresponding to one of the target languages).
  - `translated_copy`: The translated copy in the target language.
