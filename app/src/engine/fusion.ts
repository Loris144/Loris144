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
]
