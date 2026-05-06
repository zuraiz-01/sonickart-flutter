import { View, ViewStyle, StyleSheet } from 'react-native';
import React, { FC, ReactNode } from 'react';
import { SafeAreaView, Edge } from 'react-native-safe-area-context';
import colors from '../../theme/colors';

interface CustomSafeAreaViewProps {
    children: ReactNode,
    style?: ViewStyle,
    edges?: Edge[]
}

const CustomSafeAreaView: FC<CustomSafeAreaViewProps> = ({
    children,
    style,
    edges = ['top'],
}) => {
    return (
        <SafeAreaView style={[styles.container, style]} edges={edges}>
            <View style={[styles.container, style]}>{children}</View>
        </SafeAreaView>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: colors.white,
    },
});

export default CustomSafeAreaView;
