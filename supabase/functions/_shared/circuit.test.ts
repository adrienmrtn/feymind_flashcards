import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  checkCircuit,
  circuitIsOpen,
  CircuitOpenError,
  recordFailure,
  recordSuccess,
  resetCircuit,
} from "./circuit.ts";

Deno.test("le circuit s'ouvre après cinq échecs et se referme sur un succès", () => {
  resetCircuit();
  checkCircuit();

  for (let index = 0; index < 4; index += 1) recordFailure();
  checkCircuit();

  recordFailure();
  assertThrows(() => checkCircuit(), CircuitOpenError);
  assertEquals(circuitIsOpen(), true);

  recordSuccess();
  checkCircuit();
  resetCircuit();
  assertEquals(circuitIsOpen(), false);
});
