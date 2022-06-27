package com.huawei.devcloud;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

public class ReadProperties {
    private static Properties config = null;

    static {
        InputStream is = ReadProperties.class.getClassLoader().getResourceAsStream("config.properties");
        config = new Properties();
        try {
            config.load(is);
            is.close();
        } catch (IOException e2) {

        }
    }

    public static String readValue(String key) {
        try {
            return config.getProperty(key);
        } catch (Exception e) {
            return null;
        }
    }
}
