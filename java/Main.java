// A simple Java program showing Class and Object concepts

// Define a class (blueprint)
class Car {
    String color;
    String model;
    int speed;

    void accelerate() {
        speed += 10;
        System.out.println(model + " is now going " + speed + " km/h");
    }

    void brake() {
        speed -= 5;
        if (speed < 0) speed = 0;
        System.out.println(model + " slowed to " + speed + " km/h");
    }
}

public class Main {
    public static void main(String[] args) {
        // Create objects (instances of the Car class)
        Car car1 = new Car();
        car1.color = "Red";
        car1.model = "Toyota";
        car1.speed = 0;

        Car car2 = new Car();
        car2.color = "Blue";
        car2.model = "Honda";
        car2.speed = 0;

        // Use the objects
        car1.accelerate();
        car1.accelerate();
        car2.accelerate();
        car1.brake();
        car2.brake();

        System.out.println("\n" + car1.model + " is " + car1.color + " — speed: " + car1.speed + " km/h");
        System.out.println(car2.model + " is " + car2.color + " — speed: " + car2.speed + " km/h");
    }
}
