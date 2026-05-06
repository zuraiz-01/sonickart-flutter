import { StyleSheet, Image } from 'react-native';
import React, { FC } from 'react';
import Animated, { interpolate, useAnimatedStyle } from 'react-native-reanimated';
import LinearGradient from 'react-native-linear-gradient';
import { darkWeatherColors } from '@utils/Constants';
import { screenHeight, screenWidth } from '@utils/Scaling';
import { useCollapsibleContext } from '@r0b0t3d/react-native-collapsible';

const Visuals: FC = () => {

    const { scrollY } = useCollapsibleContext();
    const headerAniamtedStyle = useAnimatedStyle(() => {
        const opacity = interpolate(scrollY.value, [0, 120], [1, 0]);
        return { opacity };
    });

    return (
        <Animated.View style={[styles.container,headerAniamtedStyle]}>
            <LinearGradient colors={darkWeatherColors} style={styles.gradient} />
            <Image source={require('@assets/images/cloud.png')} style={styles.cloud} />
        </Animated.View>
    );
};

const styles = StyleSheet.create({
    container: {
        position: 'absolute',
    },
    gradient: {
        width: '100%',
        height: screenHeight * 0.4,
        position: 'absolute',
    },
    cloud: {
        width: screenWidth,
        resizeMode: 'stretch',
        height: 100,
    },
});

export default Visuals;
