import { StyleSheet } from 'react-native';
import React, { FC } from 'react';
import { StickyView, useCollapsibleContext } from '@r0b0t3d/react-native-collapsible';
import { Colors } from '@utils/Constants';
import Animated, { interpolate, useAnimatedStyle } from 'react-native-reanimated';
import SearchBar from '@components/dashboard/SearchBar';

const StickSearchBar: FC = () => {
    const { scrollY } = useCollapsibleContext();

    const animatedShadow = useAnimatedStyle(() => {
        const opacity = interpolate(scrollY.value, [0, 140], [0, 1]);
        return { opacity };
    });

    const backgroundColorChanges = useAnimatedStyle(() => {
        const opacity = interpolate(scrollY.value, [1, 80], [0, 1]);
        const r = 255, g = 255, b = 255;
        return { backgroundColor: `rgba(${r},${g},${b},${opacity})` };
    });


    return (
        <StickyView style={[backgroundColorChanges]}>
            <SearchBar />
            <Animated.View style={[styles.shadow, animatedShadow]} />
        </StickyView>
    );
};


const styles = StyleSheet.create({
    shadow: {
        height: 12,
        width: '100%',
        borderBottomWidth: 1,
        borderBottomColor: 'rgba(9,39,116,0.08)',
    },
});
export default StickSearchBar;
