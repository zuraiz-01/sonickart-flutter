import React from 'react';
import { render, fireEvent } from '@testing-library/react-native';
import SessionExpiredModal from '../SessionExpiredModal';

jest.mock('react-native-vector-icons/MaterialIcons', () => 'Icon');
jest.mock('react-native-responsive-fontsize', () => ({
  RFValue: (value: number) => value,
}));

describe('SessionExpiredModal', () => {
  const mockOnLoginAgain = jest.fn();

  beforeEach(() => {
    mockOnLoginAgain.mockClear();
  });

  it('renders correctly when visible', () => {
    const { getByText } = render(
      <SessionExpiredModal visible={true} onLoginAgain={mockOnLoginAgain} />
    );

    expect(getByText('Please login again')).toBeTruthy();
    expect(getByText('OK')).toBeTruthy();
  });

  it('does not render when not visible', () => {
    const { queryByText } = render(
      <SessionExpiredModal visible={false} onLoginAgain={mockOnLoginAgain} />
    );

    expect(queryByText('Please login again')).toBeNull();
  });

  it('calls onLoginAgain when button is pressed', () => {
    const { getByText } = render(
      <SessionExpiredModal visible={true} onLoginAgain={mockOnLoginAgain} />
    );

    fireEvent.press(getByText('OK'));
    expect(mockOnLoginAgain).toHaveBeenCalledTimes(1);
  });
});
