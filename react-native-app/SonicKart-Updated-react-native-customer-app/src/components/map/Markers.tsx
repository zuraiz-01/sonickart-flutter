import { View } from 'react-native';
import React from 'react';
import { Marker } from 'react-native-maps';
import Icon from 'react-native-vector-icons/MaterialCommunityIcons';

/**
 * Map markers for delivery destination, pickup point, and delivery partner.
 * `tracksViewChanges={false}` is intentional to keep markers stable and avoid flicker.
 */
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

const Markers = ({
    deliveryLocation,
    pickupLocation,
    deliveryPersonLocation,
    showDeliveryPartnerMarker = true,
}: any) => {
    return (
        <>
            {isValidCoordinate(deliveryLocation) && (
                <Marker
                    coordinate={deliveryLocation}
                    anchor={{ x: 0.5, y: 0.5 }}
                    tracksViewChanges={false}
                >
                    <View
                        style={{
                            alignItems: 'center',
                            justifyContent: 'center',
                        }}
                    >
                        {/* Customer / delivery address marker */}
                        <View
                            style={{
                                width: 40,
                                height: 40,
                                borderRadius: 20,
                                backgroundColor: '#F59E0B', // warm yellow for customer address
                                borderWidth: 3,
                                borderColor: '#FFFFFF',
                                shadowColor: '#000',
                                shadowOffset: { width: 0, height: 2 },
                                shadowOpacity: 0.3,
                                shadowRadius: 4,
                                elevation: 5,
                                alignItems: 'center',
                                justifyContent: 'center',
                            }}
                        >
                            <Icon name="home-map-marker" size={20} color="#FFFFFF" />
                        </View>
                    </View>
                </Marker>
            )}

            {isValidCoordinate(pickupLocation) && (
                <Marker
                    coordinate={pickupLocation}
                    anchor={{ x: 0.5, y: 0.5 }}
                    tracksViewChanges={false}
                >
                    <View
                        style={{
                            alignItems: 'center',
                            justifyContent: 'center',
                        }}
                    >
                        <View
                            style={{
                                width: 40,
                                height: 40,
                                borderRadius: 20,
                                backgroundColor: '#10B981',
                                borderWidth: 3,
                                borderColor: '#FFFFFF',
                                shadowColor: '#000',
                                shadowOffset: { width: 0, height: 2 },
                                shadowOpacity: 0.3,
                                shadowRadius: 4,
                                elevation: 5,
                                alignItems: 'center',
                                justifyContent: 'center',
                            }}
                        >
                            <Icon name="package-variant" size={18} color="#FFFFFF" />
                        </View>
                    </View>
                </Marker>
            )}

            {showDeliveryPartnerMarker && isValidCoordinate(deliveryPersonLocation) && (
                <Marker
                    coordinate={deliveryPersonLocation}
                    anchor={{ x: 0.5, y: 0.5 }}
                    tracksViewChanges={false}
                >
                    <View
                        style={{
                            alignItems: 'center',
                            justifyContent: 'center',
                        }}
                    >
                        {/* Circular background for delivery partner */}
                        <View
                            style={{
                                width: 40,
                                height: 40,
                                borderRadius: 20,
                                backgroundColor: '#007AFF',
                                borderWidth: 3,
                                borderColor: '#FFFFFF',
                                shadowColor: '#000',
                                shadowOffset: { width: 0, height: 2 },
                                shadowOpacity: 0.3,
                                shadowRadius: 4,
                                elevation: 5,
                                alignItems: 'center',
                                justifyContent: 'center',
                            }}
                        >
                            {/* Delivery boy / rider icon */}
                            <Icon name="motorbike" size={20} color="#FFFFFF" />
                        </View>
                    </View>
                </Marker>
            )}
        </>
    );
};

export default Markers;
