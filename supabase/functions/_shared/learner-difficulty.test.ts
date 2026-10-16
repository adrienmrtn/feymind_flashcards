import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { difficultyBrief, learnerBrief, readLearner, readScore } from "./learner.ts";

describe("le niveau de l'élève et ce qui le freine", () => {
  it("lit les notes en nombre, en libellé calculable, ou pas du tout", () => {
    assert.equal(readScore(42), 42);
    assert.equal(readScore(140), 100);
    assert.equal(readScore(undefined, "12/20"), 60);
    assert.equal(readScore(undefined, "75 %"), 75);
    assert.equal(readScore(undefined, "B+"), undefined);
    assert.equal(readScore("nope"), undefined);
  });

  it("garde les freins connus, une fois chacun", () => {
    const learner = readLearner({ worries: ["forgetting", "inventé", "forgetting", "examStress", 3] });
    assert.deepEqual(learner.worries, ["forgetting", "examStress"]);
    assert.equal(readLearner({}).worries, undefined);
  });

  it("un élève en difficulté reçoit des exemples pas à pas et ses prérequis", () => {
    const brief = learnerBrief(readLearner({ tier: "upperSecondary", country: "fr", currentScore: 35, scoreLabel: "7/20" }));
    assert.match(brief, /en difficulté \(niveau actuel « 7\/20 »\)/);
    assert.match(brief, /pas à pas/);
    assert.match(brief, /prérequis/);
    assert.doesNotMatch(brief, /plus exigeantes/);
  });

  it("un objectif haut ou un grand écart demande des applications plus dures et les pièges", () => {
    const high = learnerBrief(readLearner({ currentScore: 70, targetScore: 90 }));
    assert.match(high, /Il vise 90\/100/);
    assert.match(high, /pièges/);
    const gap = learnerBrief(readLearner({ scoreLabel: "8/20", targetLabel: "14/20" }));
    assert.match(gap, /en difficulté/);
    assert.match(gap, /Il vise « 14\/20 »/);
    const letter = learnerBrief(readLearner({ scoreLabel: "B", targetLabel: "A+" }));
    assert.match(letter, /Son objectif : « A\+ »/);
  });

  it("chaque frein ajoute sa phrase, et rien quand l'élève n'a rien dit", () => {
    const brief = learnerBrief(readLearner({ worries: ["hardLessons", "forgetting", "examStress", "noStart", "motivation", "homework"] }));
    assert.match(brief, /lentement, avec un exemple/);
    assert.match(brief, /flashcards/);
    assert.match(brief, /format exact de son examen/);
    assert.match(brief, /structure claire/);
    assert.match(brief, /exemples concrets/);
    assert.match(brief, /exercice type/);
    assert.equal(difficultyBrief(readLearner({ tier: "graduate" })), "");
  });
});
