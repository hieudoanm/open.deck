export const DOC_SECTIONS: { id: string; label: string }[] = [
  { id: 'getting-started', label: 'Getting started' },
  { id: 'concepts', label: 'Concepts' },
  { id: 'guides', label: 'Guides' },
];

export const sectionLabel = (id: string): string => {
  return DOC_SECTIONS.find((s) => s.id === id)?.label ?? id;
};
