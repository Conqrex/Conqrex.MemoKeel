/**
 * ReminderForm component for adding reminders with date and time pickers.
 * This component provides a better visual interface for setting reminders.
 */

import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, TextInput } from 'react-native';

const ReminderForm = ({ onSave, onCancel }) => {
  const [text, setText] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [time, setTime] = useState('');
  const [repeat, setRepeat] = useState('none');

  const handleSubmit = () => {
    if (!text.trim()) return;
    
    // Create reminder object with the selected date and time
    const reminder = {
      text: text.trim(),
      dueAt: `${date}T${time}:00`,
      repeat: repeat,
      notified: false,
      ackedAt: null,
      snoozeUntil: null,
      color: '#333',
      tagIds: [],
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      rev: 1
    };
    
    onSave(reminder);
    setText('');
    setDate(new Date().toISOString().split('T')[0]);
    setTime('');
    setRepeat('none');
  };

  const handleCancel = () => {
    onCancel();
    setText('');
    setDate(new Date().toISOString().split('T')[0]);
    setTime('');
    setRepeat('none');
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Add Reminder</Text>
      
      <View style={styles.formGroup}>
        <Text style={styles.label}>Reminder Text</Text>
        <TextInput
          style={styles.input}
          value={text}
          onChangeText={setText}
          placeholder="What needs to be done?"
          maxLength={200}
          multiline
          numberOfLines={3}
        />
      </View>
      
      <View style={styles.formGroup}>
        <Text style={styles.label}>Date</Text>
        <TextInput
          style={styles.input}
          value={date}
          onChangeText={setDate}
          placeholder="Select date"
          keyboardType="numeric"
          maxLength={10}
          textContentType="none"
        />
      </View>
      
      <View style={styles.formGroup}>
        <Text style={styles.label}>Time</Text>
        <TextInput
          style={styles.input}
          value={time}
          onChangeText={setTime}
          placeholder="HH:MM"
          keyboardType="numeric"
          maxLength={5}
          textContentType="none"
        />
      </View>
      
      <View style={styles.formGroup}>
        <Text style={styles.label}>Repeat</Text>
        <View style={styles.pickerContainer}>
          <Picker
            selectedValue={repeat}
            style={styles.picker}
            onValueChange={setRepeat}
          >
            <Picker.Item label="Never" value="none" />
            <Picker.Item label="Daily" value="daily" />
            <Picker.Item label="Weekly" value="weekly" />
            <Picker.Item label="Monthly" value="monthly" />
            <Picker.Item label="Yearly" value="yearly" />
          </Picker>
        </View>
      </View>
      
      <View style={styles.buttonContainer}>
        <TouchableOpacity style={[styles.button, styles.cancelButton]} onPress={handleCancel}>
          <Text style={styles.buttonText}>Cancel</Text>
        </TouchableOpacity>
        
        <TouchableOpacity style={[styles.button, styles.saveButton]} onPress={handleSubmit}>
          <Text style={styles.buttonText}>Add Reminder</Text>
        </TouchableOpacity>
      </View>
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
  formGroup: {
    marginBottom: 15,
  },
  label: {
    fontSize: 16,
    fontWeight: '500',
    color: '#555',
    marginBottom: 5,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    backgroundColor: '#fff',
    height: 50,
    textAlignVertical: 'top',
  },
  pickerContainer: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    backgroundColor: '#fff',
  },
  picker: {
    height: 50,
    width: '100%',
  },
  buttonContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 20,
  },
  button: {
    flex: 1,
    padding: 15,
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButton: {
    backgroundColor: '#f1f1f1',
    borderWidth: 1,
    borderColor: '#ddd',
    marginRight: 10,
  },
  saveButton: {
    backgroundColor: '#007AFF',
    marginLeft: 10,
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
});

export default ReminderForm;