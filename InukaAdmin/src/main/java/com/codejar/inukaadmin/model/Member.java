package com.codejar.inukaadmin.model;

import java.util.Date;

public class Member {
    private String id;
    private String memberNumber;
    private String fullName;
    private String idNumber;
    private String phoneNumber;
    private String email;
    private Date registrationDate;
    private String gender;
    private String zone;
    private double acreage;
    private int noTrees;
    private boolean isActive;
    private Date createdAt;
    
    public Member() {}
    
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    
    public String getMemberNumber() { return memberNumber; }
    public void setMemberNumber(String memberNumber) { this.memberNumber = memberNumber; }
    
    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }
    
    public String getIdNumber() { return idNumber; }
    public void setIdNumber(String idNumber) { this.idNumber = idNumber; }
    
    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public Date getRegistrationDate() { return registrationDate; }
    public void setRegistrationDate(Date registrationDate) { this.registrationDate = registrationDate; }
    
    public String getGender() { return gender; }
    public void setGender(String gender) { this.gender = gender; }
    
    public String getZone() { return zone; }
    public void setZone(String zone) { this.zone = zone; }
    
    public double getAcreage() { return acreage; }
    public void setAcreage(double acreage) { this.acreage = acreage; }
    
    public int getNoTrees() { return noTrees; }
    public void setNoTrees(int noTrees) { this.noTrees = noTrees; }
    
    public boolean isActive() { return isActive; }
    public void setActive(boolean active) { isActive = active; }
    
    public Date getCreatedAt() { return createdAt; }
    public void setCreatedAt(Date createdAt) { this.createdAt = createdAt; }
}
