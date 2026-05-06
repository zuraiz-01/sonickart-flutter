import { hocStyles } from '@styles/GlobalStyles';
import { FC, useEffect, useRef, useState } from 'react';
import { Animated } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';



interface CartAnimationWrapperProps {
    cartCount: number
    children: React.ReactNode
}

const CartAnimationWrapper: FC<CartAnimationWrapperProps> = ({ cartCount, children }) => {
    const insets = useSafeAreaInsets();
    const slideAnim = useRef(new Animated.Value(0)).current;

    const [hasAnimated, setHasAnimated] = useState(false);

    useEffect(() => {
        if (cartCount > 0 && !hasAnimated) {
            Animated.timing(slideAnim, {
                toValue: 1,
                duration: 300,
                useNativeDriver: true,
            }).start(() => {
                setHasAnimated(true);
            });
        } else if (cartCount === 0 && hasAnimated) {
            Animated.timing(slideAnim, {
                toValue: 0,
                duration: 300,
                useNativeDriver: true,
            }).start(() => {
                setHasAnimated(false);
            });
        }
    }, [cartCount, hasAnimated, slideAnim]);


    const slideUpStyle = cartCount > 0
        ? {
            transform: [
                {
                    translateY: slideAnim.interpolate({
                        inputRange: [0, 1],
                        outputRange: [100, 0],
                    }),
                },
            ],
            opacity: slideAnim,
        }
        : {
            transform: [{ translateY: 0 }],
            opacity: 1,
        };

    return (
        <Animated.View style={[hocStyles.cartContainer, { bottom: 120 + insets.bottom }, slideUpStyle]}>{children}</Animated.View>
    );
};

export default CartAnimationWrapper;
