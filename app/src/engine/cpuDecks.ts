export interface CpuPreset {
  id: 'yugi' | 'kaiba' | 'joey'
  name: string
  main: [number, number][] // [cardId, count]
  extra: number[]
  fillerIds: number[]
}

export const cpuPresets: CpuPreset[] = [
  {
    id: 'kaiba',
    name: 'Seto Kaiba',
    main: [
      [2, 3], [60, 3], [61, 2], [62, 2], [67, 2], [63, 1],
      [4, 2], [11, 2], [12, 2], [5, 2],
      [30, 1], [31, 1], [32, 1], [33, 1], [34, 2],
      [35, 1], [36, 2], [37, 2], [38, 1], [39, 1], [40, 1], [41, 2],
    ],
    extra: [90],
    fillerIds: [13, 9, 7],
  },
  {
    id: 'joey',
    name: 'Joey Wheeler',
    main: [
      [3, 3], [75, 2], [76, 2], [78, 2], [70, 2], [73, 2], [77, 1], [72, 1],
      [21, 2], [13, 2], [23, 2], [9, 2], [10, 2], [14, 2],
      [30, 1], [32, 1], [33, 1], [35, 1], [37, 2], [38, 1], [39, 1], [40, 1], [41, 2],
    ],
    extra: [74],
    fillerIds: [5, 6, 11],
  },
  {
    id: 'yugi',
    name: 'Yugi Muto',
    main: [
      [1, 3], [50, 2], [56, 3], [52, 1], [51, 2], [55, 1], [53, 1],
      [11, 2], [6, 2], [4, 2], [15, 2], [22, 1],
      [30, 1], [31, 1], [33, 1], [36, 2], [37, 2], [38, 1], [39, 1], [40, 1], [41, 2],
    ],
    extra: [],
    fillerIds: [5, 12, 13],
  },
]

export function buildMainDeckIds(preset: CpuPreset): number[] {
  const ids: number[] = []
  const counts = new Map<number, number>()
  for (const [cardId, count] of preset.main) {
    for (let i = 0; i < count; i++) ids.push(cardId)
    counts.set(cardId, count)
  }
  let fillerIdx = 0
  while (ids.length < 40 && preset.fillerIds.length > 0) {
    const fillerId = preset.fillerIds[fillerIdx % preset.fillerIds.length]
    const current = counts.get(fillerId) ?? 0
    if (current < 3) {
      ids.push(fillerId)
      counts.set(fillerId, current + 1)
    }
    fillerIdx++
    if (fillerIdx > 200) break
  }
  return ids
}
