import { SOCKET_URL } from '@service/config';

const optimizeCloudinaryUrl = (url: string): string => url;

/**
 * Helper function to normalize image URL (handle JSON arrays)
 * This handles cases where the backend returns image URLs as JSON array strings
 * like: '["https://example.com/image.jpg"]' instead of just the URL string
 */
export const normalizeImageUrl = (rawImage: any): string | null => {
  if (!rawImage) {return null;}

  // If it's already a string, check if it's a JSON array
  if (typeof rawImage === 'string') {
    const trimmed = rawImage.trim();
    if (!trimmed || trimmed === 'null' || trimmed === 'undefined') {
      return null;
    }

    // Check if it's a JSON array string (starts with [ and ends with ])
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        const parsed = JSON.parse(trimmed);
        if (Array.isArray(parsed) && parsed.length > 0) {
          // Get the first URL from the array
          const firstUrl = parsed[0];
          if (typeof firstUrl === 'string' && firstUrl.trim()) {
            return firstUrl.trim();
          }
        }
      } catch (e) {
        // If JSON parsing fails, continue with the original string
        console.warn('Failed to parse image JSON array:', trimmed);
      }
    }

    // Support protocol-relative URLs.
    if (trimmed.startsWith('//')) {
      return `https:${trimmed}`;
    }

    // Base64 / blob already complete.
    if (trimmed.startsWith('data:image/') || trimmed.startsWith('blob:')) {
      return trimmed;
    }

    if (trimmed.toLowerCase().startsWith('http')) {
      return optimizeCloudinaryUrl(trimmed);
    }

    // Normalize slash direction for Windows-like paths sent by backend.
    const normalizedPath = trimmed.replace(/\\/g, '/');
    const prefixedPath = normalizedPath.startsWith('/')
      ? normalizedPath
      : `/${normalizedPath}`;

    return `${SOCKET_URL}${prefixedPath}`;
  }

  // If it's already an array, get the first element
  if (Array.isArray(rawImage)) {
    if (rawImage.length > 0) {
      return normalizeImageUrl(rawImage[0]);
    }
    return null;
  }

  // If backend sends object format, pick a likely URL field.
  if (typeof rawImage === 'object') {
    const candidate =
      rawImage?.secure_url ||
      rawImage?.url ||
      rawImage?.uri ||
      rawImage?.path ||
      rawImage?.imageUrl ||
      rawImage?.image;
    if (candidate) {
      return normalizeImageUrl(candidate);
    }
  }

  // Convert to string if possible
  if (rawImage !== null && rawImage !== undefined) {
    const str = String(rawImage).trim();
    return str || null;
  }

  return null;
};
