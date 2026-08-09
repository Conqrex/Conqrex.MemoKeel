/**
 * QuickNotesReminderIntegration component for integrating reminders into the main QuickNotes application.
 * This component provides a seamless integration of the reminder functionality with the main UI.
 */

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Alert } from 'react-native';
import { ReminderUI } from '../ui/ReminderUI';

const QuickNotesReminderIntegration = ({ doc, onSave }) => {
  const [reminders, setReminders] = useState([]);

  // Initialize reminders from the document
  useState(() => {
    if (doc && doc.reminders) {
      setReminders(doc.reminders);
    }
  }, [doc]);

  // Handle saving a new reminder
  const handleSaveReminder = (reminder) => {
    // Add the new reminder to the list
    const newReminders = [...reminders, reminder];
    setReminders(newReminders);
    
    // Update the document
    const updatedDoc = {
      ...doc,
      reminders: newReminders,
      rev: (doc?.rev || 0) + 1
    };
    
    // Save the updated document
    onSave(updatedDoc);
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>QuickNotes Reminders</Text>
      
      <View style={styles.remindersSection}>
        <ReminderUI doc={doc} onSave={onSave} />
      </View>
      
      <Text style={styles.infoText}>
        Use date and time pickers to set precise reminders for your tasks.
        The system will notify you when reminders are due.
      </Text>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f8f8f8',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 20,
    textAlign: 'center',
  },
  remindersSection: {
    marginBottom: 20,
  },
  infoText: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    fontStyle: 'italic',
    marginBottom: 10,
  },
});

export default QuickNotesReminderIntegration;