package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class simplespring {

    public static void main(String[] args) {
        SpringApplication.run(simplespring.class, args);
    }

    @GetMapping("/")
    public String root() {
        return "This is the root path ('/')";
    }

    @GetMapping("/hello")
    public String hello() {
        return "Hello from your Spring Boot app!";
    }
}
