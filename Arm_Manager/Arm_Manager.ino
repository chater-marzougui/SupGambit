#include <WiFi.h> 
#include <PubSubClient.h>
#include <Servo.h>
#include <math.h>
#include <ArduinoJson.h> 

const char* ssid = "Infinix Note 7";
const char* password = "chater123";

// MQTT broker settings
const char* mqtt_server = "chateresp.broker.mqtt.lt";
const int mqtt_port = 1883;                       
const char* command_topic = "chess/moves";
const char* feedback_topic = "robot_arm/feedback";

WiFiClient espClient;
PubSubClient client(espClient);

Servo baseServo;      
Servo shoulderServo;  
Servo shoulderServo2;  // Servo for shoulder joint
Servo elbowServo;      // Servo for elbow 
Servo gripperServo;    // Servo for gripper

// Pin definitions
const int BASE_SERVO_PIN = 9;
const int SHOULDER_SERVO_PIN = 10;
const int SHOULDER2_SERVO_PIN = 6;
const int ELBOW_SERVO_PIN = 11;
const int GRIPPER_SERVO_PIN = 5;

int currentBaseAngle = 90;
int currentShoulderAngle = 90;
int currentElbowAngle = 90;
int currentGripperAngle = 60; 

const int MOVE_SPEED = 35; 
const int ANGLE_STEP = 1;  
const int SERVO_MIN_ANGLE = 0;
const int SERVO_MAX_ANGLE = 180;

const float L1 = 170.0;  // Length of first segment (mm)
const float L2 = 265.0;  // Length of second segment (mm)

// Safe height for movements
const float SAFE_HEIGHT = -50.0;  // Adjust as needed

// Square positions mapping
struct Position {
  const char* name;
  float x;
  float y;
  float z;
};

// Define the positions array
Position squarePositions[] = {
  {"x", 250, 125, -20},
  {"a1", -90, 70, -110}, {"b1", -50, 60, -110}, {"c1", -4, 30, -110}, {"d1", 3, 7, -105},
  {"e1", 8, 5, -104}, {"f1", 17, 6, -104}, {"g1", 80, 10, -110}, {"h1", 115, 10, -110},
  {"a2", -90, 85, -110}, {"b2", -50, 84, -110}, {"c2", -20, 75, -110}, {"d2", 8, 55, -110},
  {"e2", 35, 50, -110}, {"f2", 65, 50, -110}, {"g2", 90, 45, -110}, {"h2", 130, 30, -130},
  {"a3", -100, 130, -110}, {"b3", -60, 120, -110}, {"c3", -20, 110, -110}, {"d3", 15, 105, -110},
  {"e3", 35, 90, -110}, {"f3", 75, 90, -105}, {"g3", 105, 90, -105}, {"h3", 145, 90, -105},
  {"a4", -120, 150, -95}, {"b4", -70, 170, -95}, {"c4", -30, 155, -102}, {"d4", 14, 145, -105},
  {"e4", 42, 140, -100}, {"f4", 80, 130, -100}, {"g4", 120, 130, -95}, {"h4", 170, 110, -120},
  {"a5", -115, 210, -95}, {"b5", -70, 200, -95}, {"c5", -140, 190, -95}, {"d5", 6, 190, -95},
  {"e5", 40, 180, -95}, {"f5", 80, 180, -95}, {"g5", 120, 170, -120}, {"h5", 170, 160, -90},
  {"a6", -100, 240, -95}, {"b6", -60, 237, -95}, {"c6", -20, 237, -95}, {"d6", 15, 230, -97},
  {"e6", 60, 220, -97}, {"f6", 92, 200, -95}, {"g6", 140, 200, -90}, {"h6", 170, 190, -95},
  {"a7", -90, 280, -90}, {"b7", -60, 280, -90}, {"c7", -20, 270, -90}, {"d7", 24, 270, -90},
  {"e7", 75, 270, -90}, {"f7", 98, 245, -90}, {"g7", 145, 245, -90}, {"h7", 175, 230, -80},
  {"a8", -90, 315, -80}, {"b8", -45, 315, -80}, {"c8", -10, 310, -80}, {"d8", 40, 295, -85},
  {"e8", 75, 295, -85}, {"f8", 100, 280, -80}, {"g8", 150, 280, -80}, {"h8", 200, 270, -80}
};

// Number of positions
const int numPositions = sizeof(squarePositions) / sizeof(squarePositions[0]);

// Function to get position by square name
bool getPositionByName(const char* name, float& x, float& y, float& z) {
  for (int i = 0; i < numPositions; i++) {
    if (strcmp(squarePositions[i].name, name) == 0) {
      x = squarePositions[i].x;
      y = squarePositions[i].y;
      z = squarePositions[i].z;
      return true;
    }
  }
  return false; // Square not found
}

// Function to connect to Wi-Fi
void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  // Attempt to connect to Wi-Fi network
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  randomSeed(micros());
  Serial.println("\nWiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

void reconnect() {
  // Loop until reconnected
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    // Create a random client ID
    String clientId = "RobotArmClient-";
    clientId += String(random(0xffff), HEX);
    // Attempt to connect
    if (client.connect(clientId.c_str())) {
      Serial.println("connected");
      // Subscribe to the command topic
      client.subscribe(command_topic);
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println("; trying again in 5 seconds");
      // Wait 5 seconds before retrying
      delay(5000);
    }
  }
}

void moveServoSmooth(Servo& servo, int& currentAngle, int targetAngle) {
  targetAngle = constrain(targetAngle, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
  if (currentAngle < targetAngle) {
    for (int angle = currentAngle; angle <= targetAngle; angle += ANGLE_STEP) {
      servo.write(angle);
      delay(MOVE_SPEED);
    }
  } else {
    for (int angle = currentAngle; angle >= targetAngle; angle -= ANGLE_STEP) {
      servo.write(angle);
      delay(MOVE_SPEED);
    }
  }
  currentAngle = targetAngle; 
}

void moveServoSmoothShoulder(Servo& servo1, Servo& servo2, int& currentAngle, int targetAngle) {
  targetAngle = constrain(targetAngle, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
  if (currentAngle < targetAngle) {
    for (int angle = currentAngle; angle <= targetAngle; angle += ANGLE_STEP) {
      servo1.write(angle);
      servo2.write(180 - angle);
      delay(MOVE_SPEED);
    }
  } else {
    for (int angle = currentAngle; angle >= targetAngle; angle -= ANGLE_STEP) {
      servo1.write(angle);
      servo2.write(180 - angle);
      delay(MOVE_SPEED);
    }
  }
  currentAngle = targetAngle; // Update the current angle
}

// Function to toggle gripper
void toggleGripper() {
  int targetGripperAngle = (currentGripperAngle == 60) ? 110 : 60;
  moveServoSmooth(gripperServo, currentGripperAngle, targetGripperAngle);
}

// Function to move to specific servo angles
void moveToAngles(int baseAngle, int shoulderAngle, int elbowAngle, int gripperState) {
  // Move each servo smoothly to the target angle
  moveServoSmoothShoulder(shoulderServo, shoulderServo2, currentShoulderAngle, shoulderAngle);
  moveServoSmooth(baseServo, currentBaseAngle, baseAngle);
  moveServoSmooth(elbowServo, currentElbowAngle, elbowAngle);

  int targetGripperAngle = (gripperState == 0) ? 60 : 110;
  moveServoSmooth(gripperServo, currentGripperAngle, targetGripperAngle);
}

bool moveToSafeHeight(float x, float y) {
  return moveToPoint(x, y, SAFE_HEIGHT);
}

bool moveToPoint(float x, float y, float z) {
  float theta1, theta2, theta3;
  if (!inverseKinematics(x, y, z, theta1, theta2, theta3)) {
    Serial.println("Inverse kinematics calculation failed.");
    return false;
  }
  moveToAngles((int)theta1, (int)theta2, (int)theta3, currentGripperAngle == 110 ? 1 : 0);
  return true;
}

bool moveToSquare(const char* squareName, float zOverride = NAN) {
  float x, y, z;
  if (!getPositionByName(squareName, x, y, z)) {
    Serial.print("Square not found: ");
    Serial.println(squareName);
    return false;
  }
  if (!isnan(zOverride)) {
    z = zOverride;
  }
  return moveToPoint(x, y, z);
}

bool inverseKinematics(float x, float y, float z, float& theta1, float& theta2, float& theta3) {
  // Calculate base rotation angle
  theta1 = atan2(y, x) * 180.0 / PI;

  float r = sqrt(x * x + y * y);
  float d = sqrt(r * r + z * z);

  if (d > (L1 + L2)) {
    Serial.println("Target point is out of reach.");
    return false;
  }

  float angle_a = atan2(z, r);
  float angle_b = acos((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d));
  theta2 = (angle_a + angle_b) * 180.0 / PI;

  float angle_c = acos((L1 * L1 + L2 * L2 - d * d) / (2 * L1 * L2));
  theta3 = (angle_c) * 180.0 / PI;

  // Adjust theta3
  theta3 = 180.0 - theta3;

  // Constrain angles
  theta1 = constrain(theta1, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
  theta2 = constrain(theta2, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);
  theta3 = constrain(theta3, SERVO_MIN_ANGLE, SERVO_MAX_ANGLE);

  return true;
}

void callback(char* topic, byte* payload, unsigned int length) {
  // Convert the payload to a String
  String data = "";
  for (unsigned int i = 0; i < length; i++) {
    data += (char)payload[i];
  }
  data.trim(); 

  Serial.print("Received message on topic ");
  Serial.print(topic);
  Serial.print(": ");
  Serial.println(data);

  StaticJsonDocument<1024> doc;
  DeserializationError error = deserializeJson(doc, data);

  if (error) {
    Serial.print("JSON deserialization failed: ");
    Serial.println(error.c_str());
    return;
  }

  const char* command = doc["command"];

  if (strcmp(command, "moveToAngles") == 0) {
    int baseAngle = doc["baseAngle"];
    int shoulderAngle = doc["shoulderAngle"];
    int elbowAngle = doc["elbowAngle"];
    int gripperState = doc["gripperState"];

    moveToAngles(baseAngle, shoulderAngle, elbowAngle, gripperState);
    String feedback = "Moved to angles.";
    client.publish(feedback_topic, feedback.c_str());
  }
  else if (strcmp(command, "moveToPoint") == 0) {
    float x = doc["x"];
    float y = doc["y"];
    float z = doc["z"];

    if (moveToPoint(x, y, z)) {
      String feedback = "Moved to point.";
      client.publish(feedback_topic, feedback.c_str());
    } else {
      String feedback = "Failed to move to point.";
      client.publish(feedback_topic, feedback.c_str());
    }
  }
  else if (strcmp(command, "moveToSquare") == 0) {
    const char* squareName = doc["squareName"];

    if (moveToSquare(squareName)) {
      String feedback = String("Moved to square ") + squareName;
      client.publish(feedback_topic, feedback.c_str());
    } else {
      String feedback = String("Failed to move to square ") + squareName;
      client.publish(feedback_topic, feedback.c_str());
    }
  }
  else if (strcmp(command, "toggleGripper") == 0) {
    toggleGripper();
    String feedback = "Gripper toggled.";
    client.publish(feedback_topic, feedback.c_str());
  }
  else {
    Serial.println("Unknown command.");
  }
}

void setup() {
  Serial.begin(115200);

  baseServo.attach(BASE_SERVO_PIN);
  shoulderServo.attach(SHOULDER_SERVO_PIN);
  shoulderServo2.attach(SHOULDER2_SERVO_PIN);
  elbowServo.attach(ELBOW_SERVO_PIN);
  gripperServo.attach(GRIPPER_SERVO_PIN);

  // Move servos to initial neutral position
  baseServo.write(currentBaseAngle);
  shoulderServo.write(currentShoulderAngle);
  shoulderServo2.write(180 - currentShoulderAngle);
  elbowServo.write(currentElbowAngle);
  gripperServo.write(currentGripperAngle);

  Serial.println("Robot Arm with Gripper Initialized");
  setup_wifi();

  // Set MQTT server and callback
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();
}
