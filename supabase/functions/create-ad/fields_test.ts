import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { buildAdFields, FieldDefinition } from "./fields.ts";

const DEFS: FieldDefinition[] = [
  { id: 1, field_name: "area_sqm", label_ar: "المساحة", field_type: "number", is_required: true, options: null },
  { id: 2, field_name: "rooms", label_ar: "عدد الغرف", field_type: "select", is_required: true, options: ["1", "2", "3"] },
  { id: 3, field_name: "furnished", label_ar: "مفروشة", field_type: "boolean", is_required: false, options: null },
  { id: 4, field_name: "notes", label_ar: "ملاحظات", field_type: "text", is_required: false, options: null },
];

Deno.test("maps parent and subcategory fields to typed rows", () => {
  const { rows, missingRequired, invalid } = buildAdFields(DEFS, { area_sqm: "120", rooms: "3", furnished: true });
  assertEquals(missingRequired, []);
  assertEquals(invalid, []);
  assertEquals(rows.map((r) => r.field_id), [1, 2, 3]);
  assertEquals(rows[0].value_number, 120);
  assertEquals(rows[1].value_text, "3");
  assertEquals(rows[2].value_boolean, true);
});

Deno.test("reports missing required fields by label", () => {
  const { missingRequired } = buildAdFields(DEFS, { area_sqm: "", furnished: false });
  assertEquals(missingRequired, ["المساحة", "عدد الغرف"]);
});

Deno.test("rejects select values outside the options and non-numeric numbers", () => {
  const { rows, invalid } = buildAdFields(DEFS, { area_sqm: "big", rooms: "9" });
  assertEquals(invalid, ["المساحة", "عدد الغرف"]);
  assertEquals(rows.length, 0);
});

Deno.test("ignores values for fields the category does not define", () => {
  const { rows } = buildAdFields(DEFS, { area_sqm: 90, rooms: "1", brand: "تويوتا" });
  assertEquals(rows.map((r) => r.field_id), [1, 2]);
});

Deno.test("no values at all: only required fields are reported", () => {
  assertEquals(buildAdFields(DEFS, undefined).missingRequired, ["المساحة", "عدد الغرف"]);
});
