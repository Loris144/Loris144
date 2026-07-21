export interface FusionRecipe {
  resultCardId: number
  materialCardIds: number[]
}

/** Simplified: exact named-material fusions only, resolved from the activating player's hand. */
export const fusionRecipes: FusionRecipe[] = [
  { resultCardId: 90, materialCardIds: [2, 2, 2] }, // Blue-Eyes Ultimate Dragon <- 3x Blue-Eyes White Dragon
  { resultCardId: 74, materialCardIds: [3, 75] }, // Meteor Black Dragon <- Red-Eyes B. Dragon + Meteor Dragon
  { resultCardId: 91, materialCardIds: [1, 100] }, // Magician of Black Chaos <- Dark Magician + Sorcerer of Dark Magic
  { resultCardId: 120, materialCardIds: [3, 1] }, // Red-Eyes Dark Dragoon <- Red-Eyes B. Dragon + Dark Magician
  { resultCardId: 221, materialCardIds: [220, 220, 220] }, // Harpie Lady Sisters <- 3x Harpie Lady
  { resultCardId: 273, materialCardIds: [270, 271, 272] }, // Valkyrion the Magna Warrior <- Alpha + Beta + Gamma
  { resultCardId: 200, materialCardIds: [202, 203] }, // Serpent Night Dragon <- Two-Headed King Rex + Uraby
  { resultCardId: 282, materialCardIds: [4, 3] }, // Black Skull Dragon <- Summoned Skull + Red-Eyes B. Dragon
  { resultCardId: 283, materialCardIds: [6, 7] }, // Gaia the Dragon Champion <- Gaia the Fierce Knight + Curse of Dragon
  { resultCardId: 305, materialCardIds: [302, 303, 304] }, // Gate Guardian <- Sanga of the Thunder + Kazejin + Suijin
]
