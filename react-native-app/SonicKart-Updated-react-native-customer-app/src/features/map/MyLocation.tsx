import React, { FC, useEffect, useRef, useState } from 'react';
import { StyleSheet, View, Platform, Alert } from 'react-native';
import MapView, { Marker, Region } from 'react-native-maps';
import Geolocation from '@react-native-community/geolocation';
import { Colors } from '@utils/Constants';

const MyLocation: FC = () => {
  const mapRef = useRef<MapView | null>(null);
  const [region, setRegion] = useState<Region | null>(null);
  const [myCoord, setMyCoord] = useState<{ latitude: number; longitude: number } | null>(null);

  useEffect(() => {
    let watchId: any;
    try {
      Geolocation.requestAuthorization();
      watchId = Geolocation.watchPosition(
        (position) => {
          const { latitude, longitude } = position.coords;
          // Validate coordinates before using them
          if (
            typeof latitude === 'number' &&
            typeof longitude === 'number' &&
            !isNaN(latitude) &&
            !isNaN(longitude) &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180
          ) {
            const nextRegion: Region = {
              latitude,
              longitude,
              latitudeDelta: 0.01,
              longitudeDelta: 0.01,
            };
            setMyCoord({ latitude, longitude });
            setRegion(nextRegion);
            if (mapRef.current) {
              mapRef.current.animateToRegion(nextRegion, 500);
            }
          } else {
            console.warn('Invalid coordinates received:', { latitude, longitude });
          }
        },
        (error) => {
          console.log('Geolocation error', error);
          Alert.alert('Location error', 'Please enable location permissions');
        },
        { enableHighAccuracy: true, distanceFilter: 5, timeout: 10000 }
      );
    } catch (e) {
      console.log(e);
    }
    return () => {
      if (watchId) {Geolocation.clearWatch(watchId);}
    };
  }, []);

  return (
    <View style={styles.container}>
      <MapView
        ref={(ref) => (mapRef.current = ref)}
        style={StyleSheet.absoluteFill}
        provider={'google'}
        showsUserLocation={true}
        followsUserLocation={true}
        showsCompass={true}
        showsIndoors={false}
        showsMyLocationButton={Platform.OS === 'android'}
        toolbarEnabled={false}
        region={region as any}
      >
        {myCoord && (
          <Marker coordinate={myCoord} title={'You'} />
        )}
      </MapView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.backgroundSecondary,
  },
});

export default MyLocation;

