import React, { useMemo } from 'react';
import MapView, { Polyline } from 'react-native-maps';
import { customMapStyle } from '@utils/CustomMap';
import MapViewDirections from 'react-native-maps-directions';
import { GOOGLE_MAP_API } from '@service/config';
import Markers from './Markers';
import { Colors } from '@utils/Constants';
import { getPoints } from './getPoints';
import colors from '../../theme/colors';

/**
 * Shared map renderer for live tracking.
 * Draws base map, route lines, and delegates markers to `Markers`.
 */
const isValidCoordinate = (location: any): boolean => {
    if (!location) {return false;}
    const lat = Number(location.latitude);
    const lng = Number(location.longitude);
    return Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
};

const MapViewComponent = ({
    mapRef: _mapRef,
    hasAccepted,
    setMapRef,
    camera,
    deliveryLocation,
    pickupLocation,
    deliveryPersonLocation,
    hasPickedUp,
    showDeliveryPartnerMarker = true,
}: any) => {
    const initialRegion = useMemo(() => {
        const candidate =
            (isValidCoordinate(deliveryPersonLocation) && deliveryPersonLocation) ||
            (isValidCoordinate(pickupLocation) && pickupLocation) ||
            (isValidCoordinate(deliveryLocation) && deliveryLocation);

        if (!candidate) {
            return undefined;
        }

        return {
            latitude: Number(candidate.latitude),
            longitude: Number(candidate.longitude),
            latitudeDelta: 0.02,
            longitudeDelta: 0.02,
        };
    }, [deliveryPersonLocation, pickupLocation, deliveryLocation]);

    return (
        <MapView
            ref={setMapRef}
            style={{ flex: 1 }}
            provider="google"
            initialRegion={initialRegion}
            camera={camera}
            customMapStyle={customMapStyle}
            showsUserLocation={false}
            userLocationCalloutEnabled={false}
            userLocationPriority="high"
            showsTraffic={false}
            pitchEnabled={false}
            followsUserLocation={false}
            showsCompass={true}
            showsBuildings={false}
            showsIndoors={false}
            showsScale={false}
            showsIndoorLevelPicker={false}
            toolbarEnabled={false}
        >
            {deliveryPersonLocation && (hasPickedUp || hasAccepted) &&
                (hasAccepted ? pickupLocation : deliveryLocation) &&
                typeof deliveryPersonLocation?.latitude === 'number' &&
                typeof deliveryPersonLocation?.longitude === 'number' &&
                typeof (hasAccepted ? pickupLocation : deliveryLocation)?.latitude === 'number' &&
                typeof (hasAccepted ? pickupLocation : deliveryLocation)?.longitude === 'number' && (
                <MapViewDirections
                    origin={deliveryPersonLocation}
                    destination={hasAccepted ? pickupLocation : deliveryLocation}
                    precision="high"
                    apikey={GOOGLE_MAP_API}
                    strokeColor={colors.secondaryBlue}
                    strokeWidth={5}
                    onError={(err) => { console.log('MapViewDirections error:', err); }}
                />
            )}

            <Markers
                deliveryPersonLocation={deliveryPersonLocation}
                deliveryLocation={deliveryLocation}
                pickupLocation={pickupLocation}
                showDeliveryPartnerMarker={showDeliveryPartnerMarker}
            />

            {/* Dotted line between pickup and drop before the order is picked */}
            {!hasPickedUp &&
                deliveryLocation &&
                pickupLocation &&
                typeof deliveryLocation?.latitude === 'number' &&
                typeof deliveryLocation?.longitude === 'number' &&
                typeof pickupLocation?.latitude === 'number' &&
                typeof pickupLocation?.longitude === 'number' && (
                    <Polyline
                        coordinates={getPoints([pickupLocation, deliveryLocation])}
                        strokeColor={Colors.text}
                        strokeWidth={2}
                        geodesic={true}
                        lineDashPattern={[12, 10]}
                    />
                )
            }

            {/* Dotted line between rider (motorbike) and customer drop (yellow customer marker) */}
            {deliveryPersonLocation &&
                deliveryLocation &&
                typeof deliveryPersonLocation?.latitude === 'number' &&
                typeof deliveryPersonLocation?.longitude === 'number' &&
                typeof deliveryLocation?.latitude === 'number' &&
                typeof deliveryLocation?.longitude === 'number' && (
                    <Polyline
                        coordinates={getPoints([deliveryPersonLocation, deliveryLocation])}
                        // White dotted line so it stands out over the map & route
                        strokeColor={colors.white}
                        strokeWidth={2}
                        geodesic={true}
                        lineDashPattern={[6, 8]}
                    />
                )
            }

        </MapView>
    );
};

export default MapViewComponent;
