/**
 * ReminderManager component for managing reminders.
 * This component provides the logic for adding, editing, and deleting reminders.
 */

import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';
import ReminderForm from './reminders/ReminderForm';

const ReminderManager = ({ doc, onSave }) => {
  const [reminders, setReminders] = useState([]);
  const [showForm, setShowForm] = useState(false);

  // Initialize reminders from the document
  useEffect(() => {
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
    
    // Close the form
    setShowForm(false);
  };

  // Handle canceling the form
  const handleCancelForm = () => {
    setShowForm(false);
  };

  // Handle removing a reminder
  const handleRemoveReminder = (id) => {
    Alert.alert(
      "Remove Reminder",
      "Are you sure you want to remove this reminder?",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Remove",
          style: "destructive",
          onPress: () => {
            const updatedReminders = reminders.filter(r => r.id !== id);
            setReminders(updatedReminders);
            
            // Update the document
            const updatedDoc = {
              ...doc,
              reminders: updatedReminders,
              rev: (doc?.rev || 0) + 1
            };
            
            // Save the updated document
            onSave(updatedDoc);
          },
        },
      ]
    );
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Reminders</Text>
      
      <View style={styles.remindersList}>
        {reminders.length === 0 ? (
          <Text style={styles.emptyText}>No reminders yet. Add one using the button below.</Text>
        ) : (
          reminders.map((reminder) => (
            <View key={reminder.id} style={styles.reminderItem}>
              <View style={styles.reminderContent}>
                <Text style={styles.reminderText}>{reminder.text}</Text>
                <Text style={styles.reminderDue}>{reminder.dueAt ? new Date(reminder.dueAt).toLocaleString() : 'No due date'}</Text>
              </View>
              <TouchableOpacity style={styles.removeButton} onPress={() => handleRemoveReminder(reminder.id)}>
                <Text style={styles.removeButtonText}>Remove</Text>
              </TouchableOpacity>
            </View>
          ))
        )}
      </View>
      
      <TouchableOpacity style={styles.addButton} onPress={() => setShowForm(true)}>
        <Text style={styles.addButtonText}>+ Add Reminder</Text>
      </TouchableOpacity>
      
      {showForm && (
        <ReminderForm
          onSave={handleSaveReminder}
          onCancel={handleCancelForm}
        />
      )}
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
  remindersList: {
    flex: 1,
    marginBottom: 20,
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
    marginTop: 20,
  },
  reminderItem: {
    flexDirection: 'row',
    backgroundColor: '#fff',
    borderRadius: 8,
    marginBottom: 10,
    padding: 15,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
  },
  reminderContent: {
    flex: 1,
  },
  reminderText: {
    fontSize: 16,
    fontWeight: '500',
    color: '#333',
    marginBottom: 5,
  },
  reminderDue: {
    fontSize: 14,
    color: '#666',
  },
  removeButton: {
    backgroundColor: '#ff3b30',
    paddingHorizontal: 15,
    paddingVertical: 8,
    borderRadius: 6,
    justifyContent: 'center',
    alignItems: 'center',
  },
  removeButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  addButton: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 20,
  },
  addButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default ReminderManager;