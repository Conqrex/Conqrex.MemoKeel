/**
 * QuickNotesApp component for integrating reminders into the main QuickNotes application.
 * This component provides a seamless integration of the reminder functionality with the main UI.
 */

import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert } from 'react-native';
import { QuickNotesReminderIntegration } from '../ui/QuickNotesReminderIntegration';

const QuickNotesApp = () => {
  const [doc, setDoc] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // Initialize the document
  useEffect(() => {
    // Simulate loading the document
    setTimeout(() => {
      const initialDoc = {
        schemaVersion: 1,
        appVersion: "0.1.0",
        rev: 0,
        deviceId: "",
        generatedAt: "2026-07-06T10:00:00.000Z",
        ui: {},
        notes: [],
        todos: [],
        columns: [],
        cards: [],
        reminders: [],
        tags: {},
        links: [],
        attachments: {},
        trash: [],
        meta: { nextSeq: 0 }
      };
      setDoc(initialDoc);
      setIsLoading(false);
    }, 1000);
  }, []);

  // Handle saving the document
  const handleSaveDoc = (updatedDoc) => {
    setDoc(updatedDoc);
    // Simulate saving to persistence
    console.log("Document saved:", updatedDoc);
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <Text style={styles.loadingText}>Loading QuickNotes...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>QuickNotes</Text>
      
      <View style={styles.mainContent}>
        <QuickNotesReminderIntegration doc={doc} onSave={handleSaveDoc} />
      </View>
      
      <Text style={styles.footerText}>
        QuickNotes - A unified notes / to-do / kanban / reminders hub
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f8f8',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 20,
    textAlign: 'center',
  },
  mainContent: {
    flex: 1,
    padding: 20,
  },
  loadingText: {
    fontSize: 18,
    color: '#666',
    textAlign: 'center',
    marginTop: 50,
  },
  footerText: {
    fontSize: 12,
    color: '#999',
    textAlign: 'center',
    marginTop: 20,
    marginBottom: 20,
  },
});

export default QuickNotesApp;