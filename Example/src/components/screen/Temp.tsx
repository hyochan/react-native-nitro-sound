import Button from '../shared/Button';
import React from 'react';
import styled from 'styled-components/native';

const Container = styled.View`
  flex: 1;
  background-color: ${(props) => props.theme.background};
  flex-direction: row;
  align-items: center;
  justify-content: center;
`;

interface Props {
  navigation: any;
}

function Page(props: Props) {
  return (
    <Container>
      <Button
        testID='btn'
        onClick={() => props.navigation.goBack()}
        text='Go Back'
        style={{
          backgroundColor: '#333333',
        }}
      />
    </Container>
  );
}

export default Page;
