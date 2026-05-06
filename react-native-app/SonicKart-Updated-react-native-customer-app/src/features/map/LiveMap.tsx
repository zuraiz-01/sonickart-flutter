import { View, StyleSheet } from 'react-native';
import React, { FC, useEffect, useRef } from 'react';
import { screenHeight } from '@utils/Scaling';
import { Colors } from '@utils/Constants';
import { useMapRefStore } from '@state/mapStore';
import MapViewComponent from '@components/map/MapView';
import { handleFitToPath } from '@components/map/mapUtils';
import colors from '../../theme/colors';

/**
 * Customer/delivery live map wrapper.
 * Handles camera follow behavior and initial fit-to-points behavior.
 */
interface LiveMapProps {
    deliveryPersonLocation: any;
    pickupLocation: any;
    deliveryLocation: any;
    hasPickedUp: any;
    hasAccepted: any;
    iconColor?: string;
    showDeliveryPartnerMarker?: boolean;
}

const isValidCoordinate = (location: any): boolean => {
    if (!location) {return false;}
    const lat = location.latitude;
    const lng = location.longitude;
    return (
        typeof lat === 'number' &&
        typeof lng === 'number' &&
        !isNaN(lat) &&
        !isNaN(lng) &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180
    );
};

const LiveMap: FC<LiveMapProps> = ({
    deliveryLocation,
    deliveryPersonLocation,
    hasAccepted,
    hasPickedUp,
    pickupLocation,
    iconColor: _iconColor,
    showDeliveryPartnerMarker = true,
}) => {
    const { mapRef, setMapRef } = useMapRefStore();
    const previousLocationRef = useRef<any>(null);

    // Smoothly follow delivery partner when location updates
    useEffect(() => {
        if (mapRef && isValidCoordinate(deliveryPersonLocation) && (hasAccepted || hasPickedUp)) {
            const newLat = deliveryPersonLocation.latitude;
            const newLng = deliveryPersonLocation.longitude;
            const prevLat = previousLocationRef.current?.latitude;
            const prevLng = previousLocationRef.current?.longitude;

            // Only animate if location actually changed
            if (prevLat !== newLat || prevLng !== newLng) {
                // Smoothly animate camera to follow delivery partner
                mapRef.animateToRegion({
                    latitude: newLat,
                    longitude: newLng,
                    latitudeDelta: 0.01,
                    longitudeDelta: 0.01,
                }, 1000); // 1 second smooth animation

                previousLocationRef.current = { latitude: newLat, longitude: newLng };
            }
        }
    }, [mapRef, deliveryPersonLocation, deliveryPersonLocation?.latitude, deliveryPersonLocation?.longitude, hasAccepted, hasPickedUp]);

    // Initial fit to show all relevant points
    useEffect(() => {
        if (mapRef) {
            handleFitToPath(
                mapRef,
                deliveryLocation,
                pickupLocation,
                hasPickedUp,
                hasAccepted,
                deliveryPersonLocation
            );
        }
    }, [mapRef, deliveryLocation, pickupLocation, hasAccepted, hasPickedUp, deliveryPersonLocation]);


    return (
        <View style={styles.container}>
            <MapViewComponent
                mapRef={mapRef}
                setMapRef={setMapRef}
                hasAccepted={hasAccepted}
                deliveryLocation={deliveryLocation}
                pickupLocation={pickupLocation}
                deliveryPersonLocation={deliveryPersonLocation}
                hasPickedUp={hasPickedUp}
                showDeliveryPartnerMarker={showDeliveryPartnerMarker}
            />

        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        height: screenHeight * 0.35,
        width: '100%',
        borderRadius: 15,
        backgroundColor: colors.white,
        overflow: 'hidden',
        borderWidth: 1,
        borderColor: Colors.border,
        position: 'relative',
    },
    fitButton: {
        position: 'absolute',
        bottom: 10,
        right: 10,
        padding: 5,
        backgroundColor: colors.white,
        borderWidth: 0.8,
        borderColor: Colors.border,
        shadowOffset: { width: 1, height: 2 },
        shadowOpacity: 0.2,
        shadowRadius: 10,
        shadowColor: colors.black,
        elevation: 5,
        borderRadius: 35,
    },

});
export default LiveMap;
