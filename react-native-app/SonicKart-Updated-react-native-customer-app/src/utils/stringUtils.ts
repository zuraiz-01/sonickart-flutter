export const toTitleCase = (value?: string | null) => {
  if (!value) {
    return '';
  }

  return value
    .toLowerCase()
    .split(' ')
    .filter(Boolean)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

