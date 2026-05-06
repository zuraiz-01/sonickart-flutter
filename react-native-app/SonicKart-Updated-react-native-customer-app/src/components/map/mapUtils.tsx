
const isValidCoordinate = (location: any): boolean => {
    if (!location) {return false;}
    const lat = Number(location.latitude);
    const lng = Number(location.longitude);
    return Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
};

export const handleFitToPath = (
    mapRef: any,
    deliveryLocation: any,
    pickupLocation: any,
    hasPickedUp: any,
    hasAccepted: any,
    deliveryPersonLocation: any,
) => {
    if (!mapRef) {
        return;
    }

    const points = [
        hasAccepted ? deliveryPersonLocation : deliveryLocation,
        hasPickedUp ? deliveryPersonLocation : pickupLocation,
        deliveryLocation,
        pickupLocation,
        deliveryPersonLocation,
    ].filter(isValidCoordinate);

    if (points.length >= 2) {
        mapRef.fitToCoordinates(points.slice(0, 2), {
            edgePadding: { top: 50, right: 50, bottom: 50, left: 50 },
            animated: true,
        });
        return;
    }

    if (points.length === 1) {
        mapRef.animateToRegion({
            latitude: Number(points[0].latitude),
            longitude: Number(points[0].longitude),
            latitudeDelta: 0.02,
            longitudeDelta: 0.02,
        }, 500);
    }
};
