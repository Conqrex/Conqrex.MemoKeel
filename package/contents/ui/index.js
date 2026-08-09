/**
 * Main entry point for the QuickNotes application.
 * This file sets up the application and renders the main UI.
 */

import React from 'react';
import { AppRegistry } from 'react-native';
import QuickNotesApp from './ui/QuickNotesApp';

const App = () => <QuickNotesApp />;

AppRegistry.registerComponent('QuickNotes', () => App);

export default App;