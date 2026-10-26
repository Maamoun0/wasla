// Maps the wizard's dynamic field values onto ad_fields rows for the
// category's effective field definitions (parent + subcategory, from
// get_category_fields) and reports required fields that are missing.

export interface FieldDefinition {
  id: number;
  field_name: string;
  label_ar: string;
  field_type: "text" | "number" | "select" | "boolean" | "range" | "multi_select";
  is_required: boolean;
  options: unknown;
}

export interface AdFieldRow {
  field_id: number;
  value_text: string | null;
  value_number: number | null;
  value_boolean: boolean | null;
  value_json: unknown;
}

function isBlank(v: unknown): boolean {
  return v === undefined || v === null || (typeof v === "string" && v.trim() === "") ||
    (Array.isArray(v) && v.length === 0);
}

export function buildAdFields(
  definitions: FieldDefinition[],
  values: Record<string, unknown> | null | undefined,
): { rows: AdFieldRow[]; missingRequired: string[]; invalid: string[] } {
  const input = values && typeof values === "object" ? values : {};
  const rows: AdFieldRow[] = [];
  const missingRequired: string[] = [];
  const invalid: string[] = [];

  for (const def of definitions) {
    const val = input[def.field_name];
    if (isBlank(val)) {
      if (def.is_required) missingRequired.push(def.label_ar);
      continue;
    }

    const row: AdFieldRow = { field_id: def.id, value_text: null, value_number: null, value_boolean: null, value_json: null };
    switch (def.field_type) {
      case "text":
        row.value_text = String(val).trim();
        break;
      case "select": {
        const options = Array.isArray(def.options) ? def.options.map(String) : [];
        if (!options.includes(String(val))) {
          invalid.push(def.label_ar);
          continue;
        }
        row.value_text = String(val);
        break;
      }
      case "number": {
        const n = Number(val);
        if (!Number.isFinite(n)) {
          invalid.push(def.label_ar);
          continue;
        }
        row.value_number = n;
        break;
      }
      case "boolean":
        row.value_boolean = val === true || val === "true";
        row.value_text = row.value_boolean ? "نعم" : "لا";
        break;
      case "range": {
        const r = val as { min?: unknown; max?: unknown };
        row.value_json = val;
        if (r.min !== undefined && r.max !== undefined) row.value_text = `${r.min} - ${r.max}`;
        break;
      }
      case "multi_select":
        row.value_json = val;
        if (Array.isArray(val)) row.value_text = val.join(", ");
        break;
    }
    rows.push(row);
  }

  return { rows, missingRequired, invalid };
}
