import React, { FC, useCallback, useEffect, useRef, useState } from 'react';
import {
  FlatList,
  Image,
  ImageSourcePropType,
  NativeScrollEvent,
  NativeSyntheticEvent,
  StyleSheet,
  View,
} from 'react-native';
import { screenWidth } from '@utils/Scaling';
import colors from '../../theme/colors';

const AUTO_SLIDE_INTERVAL_MS = 3500;
const SLIDER_WIDTH = Math.max(screenWidth - 40, 240);
const SLIDER_HEIGHT = Math.round(SLIDER_WIDTH * 0.46);
const promoSlides: ImageSourcePropType[] = [
  require('@assets/images/slider1.jpeg'),
  require('@assets/images/slider2.jpeg'),
];

const PromoSlider: FC = () => {
  const sliderItems = promoSlides;
  const sliderRef = useRef<FlatList<ImageSourcePropType>>(null);
  const currentIndexRef = useRef(0);
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    if (sliderItems.length <= 1) {
      return;
    }

    const timer = setInterval(() => {
      const nextIndex = (currentIndexRef.current + 1) % sliderItems.length;
      sliderRef.current?.scrollToIndex({ index: nextIndex, animated: true });
      currentIndexRef.current = nextIndex;
      setActiveIndex(nextIndex);
    }, AUTO_SLIDE_INTERVAL_MS);

    return () => clearInterval(timer);
  }, [sliderItems.length]);

  const onMomentumScrollEnd = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const nextIndex = Math.round(event.nativeEvent.contentOffset.x / SLIDER_WIDTH);
      const normalizedIndex = Math.max(0, Math.min(nextIndex, sliderItems.length - 1));
      currentIndexRef.current = normalizedIndex;
      setActiveIndex(normalizedIndex);
    },
    [sliderItems.length]
  );

  if (!sliderItems.length) {
    return null;
  }

  return (
    <View style={styles.container}>
      <FlatList
        ref={sliderRef}
        data={sliderItems}
        keyExtractor={(_, index) => `promo-slide-${index}`}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={onMomentumScrollEnd}
        getItemLayout={(_, index) => ({
          length: SLIDER_WIDTH,
          offset: SLIDER_WIDTH * index,
          index,
        })}
        onScrollToIndexFailed={({ index }) => {
          setTimeout(() => {
            sliderRef.current?.scrollToIndex({ index, animated: true });
          }, 200);
        }}
        renderItem={({ item }) => (
          <View style={styles.slide}>
            <View style={styles.imageCard}>
              <Image source={item} style={styles.image} resizeMode="cover" />
            </View>
          </View>
        )}
      />
      <View style={styles.dotsRow}>
        {sliderItems.map((_, index) => (
          <View
            key={`promo-dot-${index}`}
            style={[styles.dot, index === activeIndex ? styles.dotActive : null]}
          />
        ))}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: 16,
    borderRadius: 16,
    backgroundColor: 'transparent',
  },
  slide: {
    width: SLIDER_WIDTH,
    height: SLIDER_HEIGHT,
    justifyContent: 'center',
    alignItems: 'center',
  },
  imageCard: {
    width: '100%',
    height: '100%',
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: colors.primaryBlueOpacity10,
  },
  image: {
    width: '100%',
    height: '100%',
  },
  dotsRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 6,
    marginTop: 8,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: colors.primaryBlueOpacity10,
  },
  dotActive: {
    width: 16,
    borderRadius: 999,
    backgroundColor: colors.primaryBlue,
  },
});

export default PromoSlider;
