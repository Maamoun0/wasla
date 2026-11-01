import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { scrubEvent, scrubText } from "./scrub.ts";
import { reportError } from "./error_reporting.ts";

Deno.test("scrubText removes phone numbers in any format", () => {
  for (const phone of ["01012345678", "+201012345678", "0101 234 5678", "+20-101-234-5678"]) {
    assertEquals(scrubText(`رقم ${phone} هنا`), "رقم [number] هنا");
  }
});

Deno.test("scrubText removes emails, JWTs, bearer tokens and token parameters", () => {
  assertEquals(scrubText("user a.b+c@mail.example.com failed"), "user [email] failed");
  assertEquals(scrubText("jwt eyJhbGciOi.eyJzdWIiOi.sig-part_1"), "jwt [token]");
  assertEquals(scrubText("Authorization: Bearer abc.DEF-123"), "Authorization: Bearer [token]");
  assertEquals(scrubText("url?access_token=s3cr3t&x=1"), "url?access_token=[filtered]&x=1");
  assertEquals(scrubText('{"password": "hunter2"}'), '{"password": "[filtered]"}');
  assertEquals(scrubText("HTTP 404 at line 12"), "HTTP 404 at line 12");
});

Deno.test("scrubEvent scrubs nested text, keeps only the user id and drops request details", () => {
  // deno-lint-ignore no-explicit-any
  const out = scrubEvent<Record<string, any>>({
    message: "sms to 01012345678 failed",
    exception: { values: [{ type: "Error", value: "no user x@y.com" }] },
    user: { id: "u1", email: "x@y.com", ip_address: "1.2.3.4" },
    request: { url: "https://fn.test/x?phone=010", method: "POST", headers: { authorization: "Bearer a" }, data: "{}" },
  });
  assertEquals(out.message, "sms to [number] failed");
  assertEquals(out.exception.values[0].value, "no user [email]");
  assertEquals(out.user, { id: "u1" });
  assertEquals(out.request, { url: "https://fn.test/x", method: "POST" });
});

Deno.test("reportError does nothing without SENTRY_DSN", async () => {
  Deno.env.delete("SENTRY_DSN");
  await reportError("test", new Error("boom"));
});
