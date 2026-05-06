import { View, StyleSheet, Image, TouchableOpacity } from 'react-native';
import React, { FC, useMemo, useState } from 'react';
import ScalePress from '@components/ui/ScalePress';
import { navigate } from '@utils/NavigationUtils';
import CustomText from '@components/ui/CustomText';
import { Fonts, Colors } from '@utils/Constants';
import colors from '../../theme/colors';
import { SOCKET_URL } from '@service/config';
import { normalizeImageUrl } from '@utils/imageUtils';

const MAX_VISIBLE_ROWS = 4;

const CategoryContainer: FC<{ data: any[] }> = ({ data = [] }) => {
  const [imageErrors, setImageErrors] = useState<{ [key: string]: boolean }>({});
  const [showAllRows, setShowAllRows] = useState(false);

  const rows = useMemo(() => {
    const result: any[][] = [];
    for (let i = 0; i < data.length; i += 4) {
      result.push(data.slice(i, i + 4));
    }
    return result;
  }, [data]);

  const handleImageError = (itemId: string | number) => {
    setImageErrors((prev) => ({ ...prev, [itemId]: true }));
  };

  const visibleRows = useMemo(
    () => (showAllRows ? rows : rows.slice(0, MAX_VISIBLE_ROWS)),
    [rows, showAllRows]
  );
  const shouldShowToggle = rows.length > MAX_VISIBLE_ROWS;

  if (!rows.length) {
    return (
      <View style={styles.emptyState}>
        <CustomText fontFamily={Fonts.Medium} style={styles.emptyText}>
          No categories available
        </CustomText>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {visibleRows.map((rowItems, rowIndex) => (
        <View style={styles.row} key={`row-${rowIndex}`}>
          {rowItems.map((item, index) => {
            const rawPath = normalizeImageUrl(item?.category_image);

            // If it's a relative path like "/uploads/...", prefix with SOCKET_URL
            const imageUrl =
              rawPath && !rawPath.toLowerCase().startsWith('http')
                ? `${SOCKET_URL}${rawPath}`
                : rawPath;

            const hasImage = !!imageUrl && !imageErrors[item?.id];

            return (
              <ScalePress
                onPress={() =>
                  navigate('ProductCategories', {
                    categoryId: item?.id,
                    categoryName: item?.name,
                  })
                }
                key={`${item?.id || item?.name || 'category'}-${index}`}
                style={styles.item}
              >
                <View style={styles.card}>
                  {hasImage ? (
                    <View style={styles.imageContainer}>
                      <Image
                        source={{ uri: imageUrl }}
                        style={styles.categoryImage}
                        resizeMode="cover"
                        onError={() => handleImageError(item?.id)}
                      />
                    </View>
                  ) : (
                    <View style={styles.imagePlaceholder}>
                      <CustomText
                        fontFamily={Fonts.Medium}
                        fontSize={10}
                        style={styles.placeholderText}
                      >
                        {item?.name?.charAt(0)?.toUpperCase() || 'C'}
                      </CustomText>
                    </View>
                  )}
                  <CustomText
                    fontFamily={Fonts.Medium}
                    numberOfLines={2} // clamp to 2 lines so long names don't stretch card
                    style={styles.text}
                  >
                    {item?.name || 'Category'}
                  </CustomText>
                </View>
              </ScalePress>
            );
          })}
        </View>
      ))}
      {shouldShowToggle && (
        <TouchableOpacity
          activeOpacity={0.8}
          onPress={() => setShowAllRows((prev) => !prev)}
          style={styles.viewMoreButton}
        >
          <CustomText fontFamily={Fonts.Medium} style={styles.viewMoreLabel}>
            {showAllRows ? 'View less' : 'View more'}
          </CustomText>
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginVertical: 15,
    gap: 16,
  },
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  item: {
    width: '23%', // 4 cards per row with even spacing
  },
  card: {
    backgroundColor: colors.white,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    paddingVertical: 8,
    paddingHorizontal: 8,
    alignItems: 'center',
    justifyContent: 'flex-start',
    shadowColor: colors.black,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3,
    elevation: 3,
    height: 130, // fixed height so all cards are equal, even for long names
    paddingBottom: 10,
  },
  imageContainer: {
    width: '100%',
    height: 70,
    marginBottom: 8,
    borderRadius: 8,
    overflow: 'hidden',
    backgroundColor: Colors.backgroundSecondary,
  },
  categoryImage: {
    width: '100%',
    height: '100%',
  },
  imagePlaceholder: {
    width: '100%',
    height: 70,
    marginBottom: 8,
    borderRadius: 8,
    backgroundColor: colors.primaryBlueOpacity10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  placeholderText: {
    color: colors.primaryBlue,
    fontSize: 24,
  },
  text: {
    textAlign: 'center',
    color: colors.primaryBlue,
    fontSize: 11,
    marginTop: 4,
  },
  emptyState: {
    marginVertical: 20,
    alignItems: 'center',
  },
  emptyText: {
    color: colors.primaryBlue,
  },
  viewMoreButton: {
    marginTop: 8,
    paddingVertical: 12,
    paddingHorizontal: 16,
    alignItems: 'center',
    borderRadius: 30,
    flexDirection: 'row',
    justifyContent: 'center',
    alignSelf: 'center',
    width: '60%',
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.primaryBlueOpacity10,
    shadowColor: colors.black,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 4,
    elevation: 4,
  },
  viewMoreLabel: {
    color: colors.primaryBlue,
    fontSize: 13,
  },
});
export default CategoryContainer;
